#!/usr/bin/env ruby

require 'chunky_png'
require 'optparse'
require 'pry'

VERSION = [2022, 01, 27, 00].join('.')

DEFAULT_OUTPUT_FILENAME = 'mousepad.png'
DEFAULT_WIDTH_IN_PIXELS = 1024
DEFAULT_HEIGHT_IN_PIXELS = 768
DEFAULT_LINE_THICKNESS = 2
# https://www.retrotechnology.com/herbs_stuff/sgi.html
# "..is either 85 squares per inch, or 60 squares per inch - the two in the photo. I have a few at
# about 25 squares per inch. I call these fine (85), medium (60), and coarse (25)"
#
# our grid pitch is in pixels, on the CENTRE of the lines: ignores `line_thickness`
DEFAULT_GRID_PITCH =  10

options = {
  width: DEFAULT_WIDTH_IN_PIXELS,
  height: DEFAULT_HEIGHT_IN_PIXELS,
  filename: DEFAULT_OUTPUT_FILENAME,
  include_border: true,
  separate_files: false,
  line_thickness: DEFAULT_LINE_THICKNESS,
  grid_pitch: DEFAULT_GRID_PITCH,
  color_intersections: true,
  horizontal_rgba: '0000ffff',
  vertical_rgba: 'ff0000ff',
  border_rgba: '00ff0080',
  intersection_rgba: 'ff00ffff',
  verbose: false
}

def default_line(options, opt)
  "(default: #{options[opt].inspect})"
end

opts = OptionParser.new do |opts|
  opts.banner = <<-BANNER
    Mousepad pattern generate for Mouse System mice
    Version #{VERSION} - https://github.com/xunker/mouse_system_mousepad_generator

    Unless otherwise specified, all dimensional measurements are in PIXELS.

    Usage: #{__FILE__} [options]
  BANNER
end

option_switches = [
  [
    ["-v", "--[no-]verbose"],
    "Run verbosely",
    :verbose,
    -> (options, v) { options[:verbose] = !!v }
  ],
  [
    ["-b", "--[no-]border"],
    "Add border to image output",
    :include_border,
    -> (options, v) { options[:include_border] = !!v }
  ],
  [
    ["-o FILENAME", "--output=FILENAME"],
    "Filename (or filename mask) to write",
    :filename,
    -> (options, fn) { options[:filename] = fn }
  ],
  [
    ["-H RGBA", "--horizontal-color=RGBA"],
    "Color of horizontal lines in 'rrggbbaa` hex",
    :horizontal_rgba,
    -> (options, hex) { options[:horizontal_rgba] = hex }
  ],
  [
    ["-V RGBA", "--vertical-color=RGBA"],
    "Color of vertical lines in 'rrggbbaa` hex",
    :vertical_rgba,
    -> (options, hex) { options[:vertical_rgba] = hex }
  ],
  [
    ["-I RGBA", "--intersection-color=RGBA"],
    "Color where lines intersect in 'rrggbbaa` hex",
    :intersection_rgba,
    -> (options, hex) { options[:intersection_rgba] = hex }
  ],
  [
    ["-B RGBA", "--border-color=RGBA"],
    "Color of border in 'rrggbbaa` hex",
    :border_rgba,
    -> (options, hex) { options[:border_rgba] = hex }
  ],
  [
    ["-w WIDTH", "--width=WIDTH"],
    "Width in pixels",
    :width,
    -> (options, w) { options[:width] = w.to_i }
  ],
  [
    ["-h HEIGHT", "--height=HEIGHT"],
    "Height in pixels",
    :height,
    -> (options, h) { options[:height] = h.to_i }
  ],
  [
    ["-l PIXELS", "--line-thickness=PIXELS"],
    "Line thickness in pixels",
    :line_thickness,
    -> (options, h) { options[:line_thickness] = h.to_i }
  ],
  [
    ["-p PIXELS", "--pitch=PIXELS"],
    "Pitch of the grid lines in pixels",
    :grid_pitch,
    -> (options, h) { options[:grid_pitch] = h.to_i }
  ],
  [
    ["-s", "--[no-]separate-files"],
    "Generate separate files for horizontal and vertical lines",
    :separate_files,
    -> (options, s) { options[:separate_files] = !!s }
  ]
]

option_switches.each do |switches, desc, key, blk|
  opts.on(*switches, "#{desc}") do |o|
    blk.call(options, o)
  end
end

opts.parse!

LOG_LEVELS = %i[fatal info debug]
LOG_LEVEL_PRIORITY = LOG_LEVELS.each_with_index.map{|level, priority| [level, priority]}.to_h
LOG_LEVEL = !!options[:verbose] ? LOG_LEVEL_PRIORITY[:debug] : LOG_LEVEL_PRIORITY[:info]

def log_out(msg, log_level: :info)
  return unless LOG_LEVEL >= LOG_LEVEL_PRIORITY[log_level]
  puts msg
end

def info(msg)
  log_out(msg, log_level: :info)
end

def debug(msg)
  log_out("DEBUG: #{msg}", log_level: :debug)
end

def fatal(msg)
  log_out("FATAL: #{msg}", log_level: :fatal)
end

def error(msg)
  log_out("ERROR: #{msg}", log_level: :fatal)
  exit 1
end

max_cli_flag_length = options.keys.map(&:to_s).map(&:length).max
debug("Config options:\n#{options.map{|k,v| "  #{k.to_s.rjust(max_cli_flag_length)}: #{v.inspect}"}.join("\n")}")

if options[:grid_pitch] <= options[:line_thickness]
  error "grid-pitch (#{options[:grid_pitch]}) must be > line-thickness (#{options[:line_thickness]})"
end


BACKGROUND_COLOR = ChunkyPNG::Color::TRANSPARENT
LATITUDE_COLOR = ChunkyPNG::Color.from_hex(options[:horizontal_rgba])
LONGITUDE_COLOR = ChunkyPNG::Color.from_hex(options[:vertical_rgba])
INTERSECTION_COLOR = ChunkyPNG::Color.from_hex(options[:intersection_rgba])
BORDER_COLOR = ChunkyPNG::Color.from_hex(options[:border_rgba])

def generate_grid(filename, options: {}, include_latitude: true, include_longitude: true)
  image_height = options[:height]
  image_width = options[:width]
  line_thickness = options[:line_thickness]
  grid_pitch = options[:grid_pitch]

  max_x = image_width - 1
  max_y = image_height - 1

  latitude_line_count = (image_height/grid_pitch)
  longitude_line_count = (image_width/grid_pitch)
  debug("There will be #{latitude_line_count} horizontal lines, #{longitude_line_count} vertical lines")

  latitude_start_offset = (image_height - ((latitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2
  longitude_start_offset = (image_width - ((longitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2
  debug("Latitude lines start at pixel #{latitude_start_offset}, Longitude lines start at pixel #{longitude_start_offset}")

  png = ChunkyPNG::Image.new(image_width, image_height, BACKGROUND_COLOR)

  # draw border
  if options[:include_border]
    debug("Drawing border")
    line_thickness.times do |lt|
      png.rect(0 + lt, 0 + lt , max_x - lt, max_y - lt, BORDER_COLOR, BACKGROUND_COLOR)
    end
  end

  if include_latitude
    # lines running on horizontal plane
    latitude_line_count.times do |lat_no|
      current_y_offset = latitude_start_offset + (lat_no*grid_pitch)

      debug("Latitude line starting at #{current_y_offset}")
      line_thickness.times do
        png.line(0, current_y_offset, max_x, current_y_offset, LATITUDE_COLOR)
        current_y_offset += 1
      end
    end
  end

  if include_longitude
    # lines running on vertical plane
    longitude_line_count.times do |lon_no|
      current_x_offset = longitude_start_offset + (lon_no*grid_pitch)

      debug("Latitude line starting at #{current_x_offset}")
      line_thickness.times do
        png.line(current_x_offset, 0, current_x_offset, max_y, LONGITUDE_COLOR)
        current_x_offset += 1
      end
    end
  end

  if include_latitude && include_longitude && options[:color_intersections]
    # find intersection points, color them the sum of the line colors
    (image_width/grid_pitch).times do |lon_no|
      (image_height/grid_pitch).times do |lat_no|
        current_x_offset = longitude_start_offset + (lon_no*grid_pitch)
        current_y_offset = latitude_start_offset + (lat_no*grid_pitch)

        debug("Drawing intersection point starting at x:#{current_x_offset} y:#{current_y_offset}")
        line_thickness.times do |x_offset|
          line_thickness.times do |y_offset|
            png[current_x_offset + x_offset, current_y_offset + y_offset] = INTERSECTION_COLOR
          end
        end
      end
    end
  end

  info "Writing #{filename.inspect}"
  png.save(filename, interlace: false)
end

if options[:separate_files]
  file_mask = options[:filename].split('.')
  debug("Separate files filemask is #{file_mask.inspect}")
  lat_filename = [file_mask[0], '_lat.', file_mask[1..-1].join('.')].join
  lon_filename = [file_mask[0], '_lon.', file_mask[1..-1].join('.')].join
  generate_grid(lat_filename, options: options, include_longitude: false)
  generate_grid(lon_filename, options: options, include_latitude: false)
else
  generate_grid(options[:filename], options: options)
end
