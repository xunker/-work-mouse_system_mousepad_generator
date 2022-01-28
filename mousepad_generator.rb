#!/usr/bin/env ruby

require 'chunky_png'
require 'optparse'
require 'pry'

VERSION = [2022, 01, 27, 00].join('.')

DEFAULT_OUTPUT_FILENAME = 'mousepad.png'
DEFAULT_WIDTH_IN_PIXELS = 800
DEFAULT_HEIGHT_IN_PIXELS = 600
DEFAULT_LINE_THICKNESS = 5
DEFAULT_GRID_PITCH = 90

options = {
  width: DEFAULT_WIDTH_IN_PIXELS,
  height: DEFAULT_HEIGHT_IN_PIXELS,
  filename: DEFAULT_OUTPUT_FILENAME,
  include_border: true,
  separate_files: false,
  line_thickness: DEFAULT_LINE_THICKNESS,
  grid_pitch: DEFAULT_GRID_PITCH,
  color_intersections: true,
  verbose: false
}

def default_line(options, opt)
  "(default: #{options[opt].inspect})"
end

OptionParser.new do |opts|
  opts.banner = "
Mousepad pattern generate for Mouse System mice, version #{VERSION}

Unless otherwise specified, all dimensional measurements are in PIXELS.

Usage: #{__FILE__} [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely #{default_line(options, :verbose)}") do |v|
    options[:verbose] = !!v
  end

  opts.on("-b", "--[no-]border", "Add border to image output #{default_line(options, :include_border)}") do |b|
    options[:include_border] = !!b
  end

  opts.on("-s", "--separate-files", "Generate separate files for horizontal and vertical lines #{default_line(options, :separate_files)}") do |s|
    options[:separate_files] = !!s
  end

  opts.on("-i", "--[no-]intersections", "Draw line intersections with different color #{default_line(options, :color_intersections)}") do |v|
    options[:color_intersections] = !!v
  end

  opts.on("-w WIDTH", "--width=WIDTH", "Width in pixels #{default_line(options, :width)}") do |w|
    options[:width] = w.to_i
  end

  opts.on("-h HEIGHT", "--height=HEIGHT", "Height in pixels #{default_line(options, :height)}") do |h|
    options[:height] = h.to_i
  end

  opts.on("-l PIXELS", "--line-thickness=PIXELS", "Line thickness in pixels #{default_line(options, :line_thickness)}") do |h|
    options[:line_thickness] = h.to_i
  end

  opts.on("-o FILENAME", "--output=FILENAME", "Filename (or filename mask) to write #{default_line(options, :filename)}") do |fn|
    options[:filename] = fn.to_i
  end
end.parse!

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


image_width = 800;
image_height = 600;


# https://www.retrotechnology.com/herbs_stuff/sgi.html
# "..is either 85 squares per inch, or 60 squares per inch - the two in the photo. I have a few at
# about 25 squares per inch. I call these fine (85), medium (60), and coarse (25)"
#
# our grid pitch is in pixels, on the CENTRE of the lines: ignores `line_thickness`
grid_pitch = 90#5

line_thickness = 5

BACKGROUND_COLOR = ChunkyPNG::Color::TRANSPARENT

LATITUDE_COLOR = ChunkyPNG::Color.rgb(0, 0, 255)
LONGITUDE_COLOR = ChunkyPNG::Color.rgba(255, 0, 0, 255)
# INTERSECTION_COLOR is LATITUDE_COLOR + LONGITUDE_COLOR
INTERSECTION_COLOR = ChunkyPNG::Color.rgb(255, 0, 255)
BORDER_COLOR = ChunkyPNG::Color.rgba(0, 255, 0, 128)

def generate_grid(filename, options: {}, include_latitude: true, include_longitude: true)
  image_height = options[:height]
  image_width = options[:width]
  line_thickness = options[:line_thickness]
  grid_pitch = options[:grid_pitch]

  max_x = image_width - 1
  max_y = image_height - 1

  latitude_line_count = (image_height/grid_pitch)
  debug("There will be #{latitude_line_count} horizontal lines")
  longitude_line_count = (image_width/grid_pitch)
  debug("There will be #{longitude_line_count} vertical lines")

  latitude_start_offset = (image_height - ((latitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2
  longitude_start_offset = (image_width - ((longitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2


  png = ChunkyPNG::Image.new(image_width, image_height, BACKGROUND_COLOR)

  # draw border
  if options[:include_border]
    line_thickness.times do |lt|
      png.rect(0 + lt, 0 + lt , max_x - lt, max_y - lt, BORDER_COLOR, BACKGROUND_COLOR)
    end
  end

  if include_latitude
    # lines running on horizontal plane
    latitude_line_count.times do |lat_no|
      current_y_offset = latitude_start_offset + (lat_no*grid_pitch)

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

        line_thickness.times do |x_offset|
          line_thickness.times do |y_offset|
            png[current_x_offset + x_offset, current_y_offset + y_offset] = INTERSECTION_COLOR
          end
        end
      end
    end
  end
require 'byebug'; byebug
  info "Writing #{filename.inspect}"
  png.save(filename, interlace: false)
end

if options[:separate_files]
  file_mask = options[:filename].split('.')
  lat_filename = [file_mask[0], '_lat.', file_mask[1..-1].join('.')].join
  lon_filename = [file_mask[0], '_lon.', file_mask[1..-1].join('.')].join
  generate_grid(lat_filename, options: options, include_longitude: false)
  generate_grid(lon_filename, options: options, include_latitude: false)
else
  generate_grid(options[:filename], options: options)
end
