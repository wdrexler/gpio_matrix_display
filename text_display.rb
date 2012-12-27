require './font'
require './matrix_display'
class TextDisplay
  attr_accessor :display
  def initialize(num_displays, clk_pin, data_pin, display_pins=[])
    @display_count = num_displays
    @display = MatrixDisplay.new num_displays, clk_pin, data_pin
    display_pins.each { |pin| @display.init_display display_pins.index(pin), pin, false }
    @font = Font.new 
  end

  def get_display(x)
    disp_num = 0
    if x > 23
      disp_num = x / 24
      x -= (24 * disp_num)
    end
    [disp_num, x]
  end

  def draw_char(x, y, char)
    glyph = @font.read_char char
    (0...5).each do |col|
      dots = glyph[col]
      (0...7).each do |row|
        if dots & (64>>row)
          @display.set_pixel get_display(x)[0], get_display(x)[1]+col, y+row, 1
        else
          @display.set_pixel get_display(x)[0], get_display(x)[1]+col, y+row, 0
        end
      end
    end
  end

  def draw_string(x, y, string)
    (0...string.length).each do |i|
      draw_char x, y, string[i]
      x += 6
    end
  end

  def scroll_text(string, speed)
    speed /= 1000.0
    x = 24 * @display_count
    y = 4 
    until x == (0 - string.length)
      draw_string x, y, string
      @display.sync_displays
      x -= 2
      sleep speed 
    end
  end

end
