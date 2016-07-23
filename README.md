# AudioHero

This is a ruby wrapper for [sox](http://sox.sourceforge.net/), the swiss army knife for audio.
I've implemented sensible defaults for basic operations so converting mp3 to wav is as simple as:
```ruby
AudioHero::Sox.new(mp3file).convert
```

## Installation

Requirements: Obviously, make sure your system has sox installed already.

Add this line to your application's Gemfile:

```ruby
gem 'audio_hero'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install audio_hero

## Usage

###Convert

Return the converted audio as ruby temp file object

```ruby
require "open-uri"

file = open("url/or/path/to/audio/file")

new_file = AudioHero::Sox.new(file).convert({output_options: "-c 1", output_format: "mp3", channel: "left"})
# Optional: Close the file after you are done for garbage collection.
new_file.close!

# With no options hash it will runs this command by default: `sox -t input.mp3 -c 1 -b 16 -r 16k out.wav`
AudioHero::Sox.new(file).convert
```
Options(hash):
  * channel (set "left", "right", or leave blank for stereo)
  * input_format (default to "mp3")
  * output_format (default to "wav")
  * output_options (default to "-c 1 -b 16 -r 16k", single channel, 16hz, 16bits)
  * gc (no default, set to "true" to auto close! input file)

###Remove Silence

```ruby
file = AudioHero::Sox.new(file).remove_silence({input_format: "wav", gc: "true"})
```
Options(hash):
  * silence_duration (default to 0.1 seconds)
  * silence_level (default to 0.03%)
  * input_format (default to "mp3")
  * output_format (default to "wav")
  * gc (no default, set to "true" to auto close! input file)

###Split into multiple files by silence

```ruby
file_array = AudioHero::Sox.new(file).split_by_silence({input_format: "wav", gc: "true"})
# file_array == ["path/to/out001.wav", "path/to/out002.wav"]
```
Options(hash):
  * silence_duration (default to 0.1 seconds)
  * silence_level (default to 0.03%)
  * input_format (default to "mp3")
  * output_format (default to "wav")
  * output_filename (base filename, default to "out". If using custom version of SOX, use "%,1c" for starttime and use "%1,1c-%1,1d" for starttime-endtime as filename)
  * gc (no default, set to "true" to auto close! input file)

###Stats
Get statistics report on audio file (support up to 2 channels).

```ruby
stats = AudioHero::Sox.new(file).stats({input_format: "wav"})
# {"dc_offset"=>"0.000398", "min_level"=>"-0.299591", "max_level"=>"0.303711", "pk_lev_db"=>"-10.35", "rms_lev_db"=>"-23.08", "rms_pk_db"=>"-16.19", "rms_tr_db"=>"-96.84", "crest_factor"=>"4.33", "flat_factor"=>"0.00", "pk_count"=>"2", "bit-depth"=>"15/16", "num_samples"=>"233k", "length_s"=>"14.544", "scale_max"=>"1.000000", "window_s"=>"0.050"}
```
Options(hash):
  * input_format (default to "mp3")
  * gc (no default, set to "true" to auto close! input file)

###Extract Features
Extract audio features using custom version of Yaafe script.

```ruby
features = AudioHero::Sox.new(file).extract_features({sample_rate: "8000"})
# {"feature1"=>0.34,"feature2"=>2.25}
```
Options(hash):
  * sample_rate (default to "8000")
  * gc (no default, set to "true" to auto close! input file)

###Custom Command

Run any sox command with this method.
```ruby
file = AudioHero::Sox.new(file).command({global: "-V3", input_option: "-t mp3", output_option: "-c 1", effect: "remix 0 1", gc: "true"})
# Command generated: sox -V3 -t mp3 input.mp3 -c 1 output.wav remix 0 1
```
Options(hash):
  * global (sox global options, inserted right after `sox`)
  * input_options (sox input options, inserted before input file)
  * output_options (sox output options, inserted before output file)
  * effect (sox effect, inserted after output file)
  * gc (no default, set to "true" to auto close! input file)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/litenup/audio_hero. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

