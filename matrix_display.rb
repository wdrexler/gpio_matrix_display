require 'gpio'
class MatrixDisplay
  BACKBUFFER_SIZE = 48
  CMD_SYSDIS = 0x00
  CMD_SYSON = 0x01 
  CMD_COMS11 = 0x2C
  CMD_LEDON = 0x03
  CMD_BLOFF = 0x08
  CMD_PWM = 0xA0
  ID_WR = 0x05
  ID_RD = 0x06
  ID_CMD = 0x04 

  def initialize(num_displays, clk_pin, data_pin)
    @display_count = num_displays
    
    @backbuffer_size = 8 * BACKBUFFER_SIZE
    @sz = @display_count * @backbuffer_size
    @display_buffer = []
    @display_pins = []

    @data_pin = GPIO::Pin.new :pin => data_pin, :mode => :out
    @clock_pin = GPIO::Pin.new :pin => clk_pin, :mode => :out

    bit_blast @data_pin, 1
    bit_blast @clock_pin, 1
  end

  def get_pixel(display_num, x, y)
    address = xy_to_index x, y
    address += BACKBUFFER_SIZE * display_num
    bit = calc_bit y
    
    address *= 2
    value = @display_buffer[address]

    (value & bit) ? 1 : 0
  end

  def set_pixel(display_num, x, y, value, paint=false)
    address = xy_to_index x, y
    disp_address = address
    address += BACKBUFFER_SIZE * display_num
    bit = calc_bit y
    if value
      @display_buffer[address] |= bit
    else
      @display_buffer[address] &= ~bit
    end

    if paint
      disp_address = display_xy_to_index x, y
      value = @display_buffer[address]
      value = @display_buffer[address] >> 4 if (y >> 2) & 1
      write_nibbles display_num, disp_address, value, 1
    end
  end

  def init_display(display_num, pin, is_master)
    @display_pins[display_num] = GPIO::OutputPin.new pin
    bit_blast @display_pins[display_num], 1
    select_display display_num

    write_data_msb 8, CMD_SYSDIS, true
    write_data_msb 8, CMD_SYSON, true
    write_data_msb 8, CMD_COMS11, true
    write_data_msb 8, CMD_LEDON, true
    write_data_msb 8, CMD_BLOFF, true
    write_data_msb 8, CMD_PWM+15, true

    release_display display_num
    clear display_num, true
  end

  def sync_displays
    buffer_offset = 0
    value = 0
    (0...@display_count).each do |disp_num|
      buffer_offset = BACKBUFFER_SIZE * disp_num
      select_display disp_num
      write_data_msb 3, ID_WR
      write_data_msb 7, 0
      (0...BACKBUFFER_SIZE).each do |addr|
        value = @display_buffer[addr + buffer_offset]
        write_data_lsb 8, value
      end
      release_display disp_num
    end
  end

  def write_nibbles(display_num, addr, data, nybble_count)
    select_display display_num
    write_data_msb 3, ID_WR
    write_data_msb 7, addr
    (0...nybble_count).each { |i| write_data_lsb 4, data[i] }
    release_display display_num
  end

  def clear(display_num, paint=false)
    @display_buffer[BACKBUFFER_SIZE * display_num] = nil 
    sync_displays if paint
  end

  def clear(paint=true)
    @display_buffer = [] 
    if paint
      (0...@display_count).each { |i| select_display i }
      write_data_msb 3, ID_WR
      write_data_msb 7, 0
      (0...48).each { |i|  write_data_lsb 8, 0 }
      (0...@display_count).each { |i| release_display i }
    end
  end

  def get_display_count
    @display_count
  end

  def get_display_height
    16
  end

  def get_display_width
    24
  end

  def shift_left
    @display_buffer.shift 2
    @display_buffer << 0 << 0
  end

  def shift_right
    @display_buffer.unshift(0, 0)
  end

  def set_brightness(disp_num, pwm_value)
    pwm_value = (pwm_value > 15) ? 15 : pwm_value
    pwm_value = (pwm_value < 0) ? 0 : pwm_value
    select_display disp_num
    pre_command
    write_data_msb 8, CMD_PWM+pwm_value, true
    release_display disp_num
  end

  private

  def calc_bit(y)
    1 << (y > 7 ? (y-8) : y)
  end

  def xy_to_index(x, y)
    x = (x > 23) ? 23 : x
    y &= 0xF

    address = (y > 7) ? 1 : 0
    address += x << 1
    address
  end

  def display_xy_to_index(x, y)
    address = (y == 0) ? 0 : (y / 4)
    address += x << 2
    address
  end

  def select_display(display_num)
    bit_blast @display_pins[display_num], 0
  end

  def release_display(display_num)
    bit_blast @display_pins[display_num], 1
  end

  def write_data_msb(bit_count, data, use_nop=false)
    (bit_count-1).downto(0).each do |i|
      bit_blast @clock_pin, 0
      bit_blast @data_pin, (data >> i) & 1
      bit_blast @clock_pin, 1
    end

    if use_nop
      bit_blast @clock_pin, 0
      sleep 0.002
      bit_blast @clock_pin, 1
  end

  def write_data_lsb(bit_count, data)
    (1...bit_count).each do |i|
      bit_blast @clock_pin, 0
      bit_blast @data_pin, ((data >> i) & 1)
      bit_blast @clock_pin, 1
    end
  end

  def write_command(display_num, command)
    select_display display_num
    bit_blast @data_pin, 1
    write_data_msb 3, ID_CMD
    write_data_msb 8, command
    write_data_msb 1, 0
    bit_blast @data_pin, 0
    release_display display_num
  end

  def bit_blast(pin, data)
    pin.device.write pin.device.software_pin, (data & 0x01)
  end

  def pre_command
    bit_blast @clock_pin, 0
    bit_blast @data_pin, 1
    sleep 0.001

    bit_blast @clock_pin, 1
    sleep 0.002

    bit_blast @clock_pin, 0
    bit_blast @data_pin, 0
    sleep 0.001

    bit_blast @clock_pin, 1
    sleep 0.002

    bit_blast @clock_pin, 0
    bit_blast @data_pin, 0
    sleep 0.001
    bit_blast @clock_pin, 1
    sleep 0.002
  end
end
