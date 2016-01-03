require "audio_hero/version"
require 'cocaine'
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
      @basename = File.basename(@file.path)
    end

    # Usage: file = AudioHero::Sox.new(file).convert({output_options: "-c 1 -b 16 -r 16k", output_format: "mp3", channel: "left"}); file.close
    def convert(options={})
      channel = options[:channel]
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      output_format = options[:output_format] ? options[:output_format] : "wav"
      output_options = options[:default] ? "-c 1 -b 16 -r 16k" : options[:output_options]
      case channel
      when "left"
        channel = "remix 1 0"
      when "right"
        channel = "remix 0 1"
      else
        channel = nil
      end
      src = @file
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
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => File.expand_path(src.path), :dest => File.expand_path(dst.path))
      rescue => e
        raise AudioHeroError, "There was an error converting #{@basename} to #{output_format}"
      end
      src.close! if options[:gc] == "true"
      dst
    end

    # Usage: file = AudioHero::Sox.new(file).remove_silence
    def remove_silence(options={})
      silence_duration = options[:silence_duration] || "0.1"
      silence_level = options[:silence_level] || "0.03"
      effect = "silence 1 #{silence_duration} #{silence_level}% -1 #{silence_duration} #{silence_level}%"
      input_format = options[:input_format] ? options[:input_format] : "mp3"
      output_format = options[:output_format] ? options[:output_format] : "wav"

      # Default to wav
      src = @file
      # Default conversion to wav
      dst = Tempfile.new(["out", ".#{output_format}"])
      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << ":dest"
        parameters << effect
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => File.expand_path(src.path), :dest => File.expand_path(dst.path))
      rescue => e
        raise AudioHeroError, "There was an error converting #{@basename} to #{output_format}"
      end
      src.close! if options[:gc] == "true"
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
      file2 = options[:file2]
      # Default to wav
      dir = Dir.mktmpdir
      format = output_format ? ".#{output_format}" : ".wav"
      dst = "#{dir}/out#{format}"

      src = @file
      src2 = file2

      begin
        parameters = []
        parameters << "-t #{input_format}"
        parameters << ":source"
        parameters << ":dest"
        parameters << effect
        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => File.expand_path(src.path), :dest => dst)
        success = Cocaine::CommandLine.new("sox", parameters).run(:source => File.expand_path(src2.path), :dest => dst) if src2
      rescue => e
        raise AudioHeroError, "There was an error splitting #{@basename}"
      end
      src.close! && src2.close! if options[:gc] == "true"
      Dir["#{dir}/**/*#{format}"]
    end

    def command(options={})
      global = options[:global_options]
      input_options = options[:input_options]
      output_options = options[:output_options]
      effect = options[:effect]
      output_format = options[:output_format] ? options[:output_format] : "wav"
      src = @file

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
        command = sox.command(source: File.expand_path(src.path), dest: File.expand_path(dst.path))
        success = sox.run(source: File.expand_path(src.path), dest: File.expand_path(dst.path))
      rescue => e
        raise AudioHeroError, "There was an error excuting command: #{command}"
      end
      src.close! if options[:gc] == "true"
      dst
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
