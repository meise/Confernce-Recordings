# encoding: UTF-8
=begin
Copyright Daniel Meißner <dm@3st.be>, 2011

This file is part of a Encodaem script for video handling.

This script is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This Script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Encodaem.  If not, see <http://www.gnu.org/licenses/>.
=end


require 'rubygems'
require 'daemons'
require 'nokogiri'
require 'fileutils'

class Encoder
  # encode the raw.dv file
  def encode (talk, daemon)
    # transfer the raw.dv file one time from the nfs share to local tmp file
    if system("scp -l #{daemon.limit} #{daemon.cut_directory}/#{talk.talk_id}.dv #{daemon.tmp}/#{talk.talk_id}.dv")
      puts "Copied #{daemon.cut_directory}/#{talk.talk_id}.dv to #{daemon.tmp}. Ready to encode..."

      # encode the talk in all formats
      if system("python ../encoding/encH264.py -i #{talk.talk_id} -o #{daemon.tmp} -v #{daemon.tmp} -t #{daemon.cpu_cores}")
        if system("python ../encoding/encWebM.py -i #{talk.talk_id} -o #{daemon.tmp} -v #{daemon.tmp} -t #{daemon.cpu_cores}")
          if system("python ../encoding/encTheora.py -i #{talk.talk_id} -o #{daemon.tmp} -v #{daemon.tmp} -t #{daemon.cpu_cores}")
            # TODO: Send notification all formats encoded to WebApp
            puts "Encoded all formats successful".color('green')

            # if everything is successful encoded, copy all encodes to the nfs share
            if system("scp -L #{daemon.limit} *.mp4 #{daemon.encoded_directory}/H264/")
              if system("scp -L #{daemon.limit} *.webm #{daemon.encoded_directory}/WebM/")
                if system("scp -L #{daemon.limit} *.ogv #{daemon.encoded_directory}/Theora/")
                  puts "All encodes for talk #{talk.talk_id} copied to #{daemon.encoded_directory}/".color('green')
                else
                  "Error: Could not copy #{talk.talk_id} WebM file to #{daemon.encoded_directory}/WebM/".color('red')
                end
              else
                 "Error: Could not copy #{talk.talk_id} Theora file to #{daemon.encoded_directory}/Theora/".color('red')
              end

              else
                "Error: Could not copy #{talk.talk_id} mp4 file to #{daemon.encoded_directory}/H264/".color('red')
            end

          # Errors for the encoding task
          else
            # TODO: Send encoding error by Theora to WebApp
            puts "Error: H264 encode".color('red')
          end
        else
          # TODO: Send encoding error by WebM to WebApp
          puts "Error: H264 encode".color('red')
        end
      else
        # TODO: Send encoding error by H264 to WebApp
        puts "Error: H264 encode".color('red')
      end

    # Error for the copy task
    else
      puts "Error: Could not copied #{daemon.cut_directory}/#{talk.talk_id}.dv to #{daemon.tmp}."
    end

  end
end

class Cutter
  # cuts all files to one
  def cut (talk, daemon)
    files = ''

    # build a string of all given talk files
    talk.files.each do |file|
      files += "#{daemon.recorded_directory}" + file + " "
    end

    # concatenate all files
    if system("cat #{files} > #{daemon.cut_directory}/#{talk.talk_id}.dv")
      puts "Concatenated all given files to talk #{talk.talk_id} to one.  #{daemon.cut_directory}/#{talk.talk_id}.dv"
    else
      puts "Error: Files to talk #{talk.talk_id} could not be concatenate."
    end
  end
end

class PreRoller
  # creates the pre-roll and adds it to the complete talk
  # you should cut all files of a talk to a big one before you create the pre-roll
  def create_pre_roll (talk, daemon)
    if system("python ../prerole/genPrerole.py -i #{talk.talk_id} -o #{daemon.encoded_directory}/H264 -v #{daemon.cut_directory} -t #{daemon.cpu_cores}")
      # TODO: Send pre roll created message into logfile
      puts "Pre roll created".color('green')
    else
      # TODO: Log pre roll created error into logfile
      puts "Error: Pre roll creation fails!".color('red')
    end

  end
end

class Talk

  attr_accessor :talk_id, :slug, :speakers, :files, :start, :end, :work

  def initialize
    @talk_id = ''
    @slug = ''
    @speakers = []
    @files = []
    @start = ''
    @end = ''
    @work = ''
  end
end

class Parser

  def initialize 
    @doc = Nokogiri.parse(File.open("/home/dm/projects/Confernce-Recordings/worker_daemon/examples/jobs.xml"))
  end

  def parse
    @talk = Talk.new


    if @doc.xpath("//jobs/job").length == 0
      nil # is returned if there is a xml file which we haven't expected
    else
      @doc.xpath("//jobs/job").each do |job|

        job.xpath("//work").each do |work|
          @talk.work = work.text.to_s
        end

        job.xpath("//talk").each do |talk|
          # puts talk.values
          @talk.talk_id = talk.values.join
          talk.xpath("//slug").each do |slug|
            # puts slug.text.to_s
            @talk.slug = slug.text.to_s
          end

          @talk.speakers = []

          talk.xpath("//speaker").each do |speaker|

            tmp_speaker = ''

            speaker.xpath("//forename").each do |forename|
               tmp_speaker += forename.text.to_s
            end

            speaker.xpath("//surname").each do |surname|

                tmp_speaker += " " + surname.text.to_s
            end

            @talk.speaker << tmp_speaker

          end
          @talk.files = []

          talk.xpath("//recordings").each do |recording|

            recording.xpath("//file").each do |file|
              # files_to_cat << file.text.to_s
              @talk.files << file.text.to_s
            end
          end
          # puts files_to_cat.to_s
        end
      end
      @talk
    end
  end


end

class Daemon

  attr_reader :management_server, :cut_directory, :encoded_directory, :recorded_directory, :new_task_url, :error_url, :work_done_url, :cpu_cores, :host_id

  def initialize
    # define management server parameters

    @management_server = "http://localhost/"
    @new_task_url = "new_task"
    @error_url = "error"
    @work_done_url = "work_done"

    # working directory
    @landing_zone = "/home/dm/projects/Confernce-Recordings/worker_daemon/"
    @cut_directory = "#{@landing_zone}cutted"
    @encoded_directory = "#{@landing_zone}encoded"
    @recorded_directory = "#{@landing_zone}recorded"
    @tmp_directory = "#{@landing_zone}tmp"

    # the cpu count is used for the ffmpeg thread function
    @cpu_cores = find_cpu_cores
    @host_id = ''

    # 10 mbit transfer limitation from and to the nfs share
    @limit = '10240'

    check_directory

  end

  private

  def check_directory
    if not File.directory?(@landing_zone)
      Dir.mkdir(@landing_zone)
      # TODO: Logfile output
    end

    if not File.directory?(@cut_directory)
      Dir.mkdir(@cut_directory)
      # TODO: Logfile output
    end

    if not File.directory?(@recorded_directory)
      Dir.mkdir(@recorded_directory)
      # TODO: Logfile output
    end

    if not File.directory?(@tmp_directory)
      Dir.mkdir(@tmp_directory)
      # TODO: Logfile output
    end

    if not File.directory?(@encoded_directory)
      Dir.mkdir(@encoded_directory)
      ["H264", "Theora", "WebM"].each do |dir|
        Dir.mkdir("#{@encoded_directory}/#{dir}")
      end
      # TODO: Logfile output
    end
  end

  def find_cpu_cores
    @cpu_cores = 0
    File.open("/proc/cpuinfo", "r").each_line do |line|
      if /^processor/ =~ line
        @cpu_cores += 1
      end
    end
    @cpu_cores
  end
end

begin
  daemon = Daemon.new

  # default sleeping timer, if there is no new job available or the management server is not reachable
  sleep_timer = 100

  # run till somebody stop the process
  loop do
    parser = Parser.new

    # parsing should be successful
    if talk = parser.parse

      case talk.work
        when 'encode'
          Encoder.new.encode(talk, daemon)
        when 'cutting'
          Cutter.new.cut(talk, daemon)
        when 'pre_roll'
          PreRoller.new.create_pre_roll(talk, daemon)
      end

      # reset sleeping timer
      sleep_timer = 100

    else
      # delaying next new work call on the management server
      sleep(sleep_timer)

      # double the sleeping timer, so that it counteract a dos situation on the management server
      if sleep_timer < 900 # 15 minutes
        sleep_timer += sleep_timer
      else
        sleep_timer = 100
      end
    end
  end
end
