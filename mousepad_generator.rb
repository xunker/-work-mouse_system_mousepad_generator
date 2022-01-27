#!/usr/bin/env ruby

require 'chunky_png'

# unless otherwise specified, all dimensional measurements are in PIXELS
image_width = 800;
image_height = 600;

max_x = image_width - 1
max_y = image_height - 1

# https://www.retrotechnology.com/herbs_stuff/sgi.html
# "..is either 85 squares per inch, or 60 squares per inch - the two in the photo. I have a few at
# about 25 squares per inch. I call these fine (85), medium (60), and coarse (25)"
#
# our grid pitch is in pixels, on the CENTRE of the lines: ignores `line_thickness`
grid_pitch = 90#5

line_thickness = 5

background_color = ChunkyPNG::Color::TRANSPARENT
# background_color = ChunkyPNG::Color.html_color(:white)
latitude_color = ChunkyPNG::Color.rgb(0, 0, 255)
longitude_color = ChunkyPNG::Color.rgba(255, 0, 0, 255)
# intersection_color is latitude_color + longitude_color
intersection_color = ChunkyPNG::Color.rgb(255, 0, 255)
border_color = ChunkyPNG::Color.rgba(0, 255, 0, 128)

latitude_line_count = (image_height/grid_pitch)
longitude_line_count = (image_width/grid_pitch)

latitude_start_offset = (image_height - ((latitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2
longitude_start_offset = (image_width - ((longitude_line_count*grid_pitch)-grid_pitch+line_thickness))/2

png = ChunkyPNG::Image.new(image_width, image_height, background_color)

# draw border
line_thickness.times do |lt|
  png.rect(0 + lt, 0 + lt , max_x - lt, max_y - lt, border_color, background_color)
end

# lines running on horizontal plane
latitude_line_count.times do |lat_no|
  current_y_offset = latitude_start_offset + (lat_no*grid_pitch)

  line_thickness.times do
    png.line(0, current_y_offset, max_x, current_y_offset, latitude_color)
    current_y_offset += 1
  end
end

# lines running on vertical plane
longitude_line_count.times do |lon_no|
  current_x_offset = longitude_start_offset + (lon_no*grid_pitch)

  line_thickness.times do
    png.line(current_x_offset, 0, current_x_offset, max_y, longitude_color)
    current_x_offset += 1
  end
end

# find intersection points, color them the sum of the line colors
(image_width/grid_pitch).times do |lon_no|
  (image_height/grid_pitch).times do |lat_no|
    current_x_offset = longitude_start_offset + (lon_no*grid_pitch)
    current_y_offset = latitude_start_offset + (lat_no*grid_pitch)

    line_thickness.times do |x_offset|
      line_thickness.times do |y_offset|
        png[current_x_offset + x_offset, current_y_offset + y_offset] = intersection_color
      end
    end
  end
end

png.save('mousepad.png', interlace: false)
