require "audio_hero/version"
require 'cocaine'
require 'msgpack'
require 'tempfile'

# test file: http://s3.amazonaws.com/recordings_2013/5204aebc-a9e9-11e5-baad-842b2b17453e.mp3
# Usage: file = open("url"); AudioHero::Sox.new(file);

module AudioHero
  class AudioHeroError < StandardError
  end
  class Sox
    attr_accessor :file, :params, :output_format

    def initialize(file, options={})
      @file = file
      @basename = get_basename(file)
    end

    # Usage: file = AudioHero::Sox.new(file).convert({output_options: "-c 1 -b 16 -r 16k", output_format: "mp3", channel: "left"}); file.close
    def convert(options={})
      channel = options[:channel]
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      output_format = options[:output_format] ? options[:output_format] : "wav"
      output_options = options[:default] ? "-c 1 -b 16 -r 16k" : options[:output_options]
      case channel
      when "left"
        channel = "remix 1"
      when "right"
        channel = "remix 2"
      else
        channel = nil
      end

      # Default conversion to wav
      dst = Tempfile.new(["out", ".#{output_format}"])
      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << output_options if output_options
        parameters << ":dest"
        parameters << channel if channel
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => get_path(@file), :dest => get_path(dst))
      rescue => e
        raise AudioHeroError, "There was an error converting #{@basename} to #{output_format}"
      end
      garbage_collect(@file) if options[:gc] == "true"
      dst
    end

    # Usage: file = AudioHero::Sox.new(file).remove_silence
    def remove_silence(options={})
      silence_duration = options[:silence_duration] || "0.1"
      silence_level = options[:silence_level] || "0.03"
      effect = "silence 1 #{silence_duration} #{silence_level}% -1 #{silence_duration} #{silence_level}%"
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      output_format = options[:output_format] ? options[:output_format] : "wav" # Default to wav

      dst = Tempfile.new(["out", ".#{output_format}"])
      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << ":dest"
        parameters << effect
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => get_path(@file), :dest => get_path(dst))
      rescue => e
        raise AudioHeroError, "There was an error converting #{@basename} to #{output_format}"
      end
      garbage_collect(@file) if options[:gc] == "true"
      dst
    end

    # Usage: AudioHero::Sox.new(file).split_by_silence({input_format: "wav"})
    # Returns an array of the full path of the splitted files, can split two input files at one go using {file2: file} option.
    # Remember its good practice to remove the temp directory after use.
    # FileUtils.remove_entry tempdir

    def split_by_silence(options={})
      silence_duration = options[:silence_duration] || "0.5"
      silence_level = options[:silence_level] || "0.03"
      effect = "silence 1 #{silence_duration} #{silence_level}% 1 #{silence_duration} #{silence_level}% : newfile : restart"
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      output_format = options[:output_format]
      output_filename = options[:output_filename] || "out"
      # Default to wav
      dir = Dir.mktmpdir
      format = output_format ? ".#{output_format}" : ".wav"
      dst = "#{dir}/#{output_filename}#{format}"

      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << ":dest"
        parameters << effect
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => get_path(@file), :dest => dst)
      rescue => e
        raise AudioHeroError, "There was an error splitting #{@basename}"
      end
      garbage_collect(@file) if options[:gc] == "true"

      Dir["#{dir}/**/*#{format}"]
    end

    # Concat takes in an array of audio files (same format) and concatenate them.
    def concat(options={})
      output_format = options[:output_format] ? options[:output_format] : "wav"
      dst = Tempfile.new(["out", ".#{output_format}"])
      _file_array = get_array(@file)
      begin
        parameters = _file_array
        parameters << ":dest"
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:dest => get_path(dst))
      rescue => e
        raise AudioHeroError, "There was an error joining #{@file}"
      end
      # no garbage collect option for join
      dst
    end

    def stats(options={})
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << "-n stats"
        parameters << "2>&1" # redirect stderr to stdout
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => get_path(@file))
      rescue => e
        raise AudioHeroError, "These was an issue getting stats from #{@basename}"
      end
      garbage_collect(@file) if options[:gc] == "true"
      parse_stats(success)
    end

    # Requires custom version of yaafe
    def extract_features(options={})
      rate = options[:sample_rate] || "8000"
      begin
        parameters = []
        parameters << "-r #{rate}"
        parameters << ":source"
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("yaafehero", parameters).run(:source => get_path(@file))
      rescue => e
        raise AudioHeroError, "These was an issue getting stats from #{@basename}"
      end
      garbage_collect(@file) if options[:gc] == "true"
      MessagePack.unpack(success)
    end

    def command(options={})
      global = options[:global_options]
      input_options = options[:input_options]
      output_options = options[:output_options]
      effect = options[:effect]
      output_format = options[:output_format] ? options[:output_format] : "wav"

      # Default to wav
      dst = Tempfile.new(["out", ".#{output_format}"])
      begin
        parameters = []
        parameters << global if global
        parameters << input_options if input_options
        parameters << ":source"
        parameters << output_options if output_options
        parameters << ":dest"
        parameters << effect if effect
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        sox = Cocaine::CommandLine.new("sox", parameters)
        command = sox.command(:source => get_path(@file), :dest => get_path(dst))
        success = sox.run(:source => get_path(@file), :dest => get_path(dst))
      rescue => e
        raise AudioHeroError, "There was an error excuting command: #{command}"
      end
      garbage_collect(@file) if options[:gc] == "true"
      dst
    end

    private

    def get_basename(file)
      case file
      when String
        File.basename(file)
      when Tempfile
        File.basename(file.path)
      when File
        File.basename(file.path)
      when Array
        nil
      else
        raise AudioHeroError, "Unknown input file type #{file.class}"
      end
    end

    def get_path(file)
      case file
      when String
        File.expand_path(file)
      when Tempfile
        File.expand_path(file.path)
      when File
        File.expand_path(file.path)
      else
        raise AudioHeroError, "Unknown input file type #{file.class}"
      end
    end

    def get_array(file)
      case file
      when Array
        file
      else
        raise AudioHeroError, "Unknown input file type #{file.class}"
      end
    end

    def garbage_collect(file)
      case file
      when String
        File.delete(file)
      when Tempfile
        file.close!
      when File
        File.delete(file.path)
      else
        raise AudioHeroError, "Unknown input file type #{file.class}"
      end
    end

    def parse_stats(stats)
      hash = Hash.new { |h, k| h[k] = {} }
      if stats.include? "Left"
        stats.split("\n").drop(1).each do |row|
          overall = hash[:overall]
          left = hash[:left]
          right = hash[:right]
          array = row.split(" ")
          if array.count == 4
            label = array[0].downcase!
            overall[label] = array[1]
            left[label] = array[2]
            right[label] = array[3]
          elsif array.count > 4
            label = array.first(array.count - 3).join(" ").gsub!(/( )/, '_').downcase!
            values = array.last(3)
            overall[label] = values[0]
            left[label] = values[1]
            right[label] = values[2]
          else
            label = array.first(array.count - 1).join(" ").gsub!(/( )/, '_').downcase!
            overall[label] = array.last
            left[label] = array.last
            right[label] = array.last
          end
        end
      else
        stats.split("\n").each do |row|
          array = row.split(" ")
          if array.count == 2
            hash[array.first.downcase!] = array.last
          elsif array.count > 2
            hash[array.first(array.count - 1).join(" ").gsub!(/( )/, '_').downcase!] = array.last
          end
        end
      end
      hash
    end

  end
end


# Usage: file = AudioHero::Sox.new(file).convert({output_options: "-c 1 -b 16 -r 16k", output_format: "mp3", channel: "left"}); file.close
# sox required for AudioHero to work.
# '-c 1' specifies the output file to have 1 channel
# 'remix' selects and mixes input audio channels into output audio channels
# 1 0 means output 2 channels, channel one is a copy of original channel 1, while channel two is slient.
# left channel - sox input.mp3 -c 1 -b 16 -r 16k output.wav remix 1 0
# right channel - sox input.mp3 -c 1 -b 16 -r 16k output.wav remix 0 1

# split file by sentence while cutting silence: sox -V3 original.mp3 out2.wav silence 1 0.5 0.03% 1 0.5 0.03% : newfile : restart
# Cut out silence without splitting: sox -V3 original.mp3 out2.wav silence 1 0.5 0.03% -1 0.5 0.03%
# all following read a file
# open("url")
# File.open("filepath", "rb")
# open("file")
