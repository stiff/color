# An RGB colour object.
class Color::RGB
  include Color

  # The format of a DeviceRGB colour for PDF. In color-tools 2.0 this will
  # be removed from this package and added back as a modification by the
  # PDF::Writer package.
  PDF_FORMAT_STR  = "%.3f %.3f %.3f %s"

  # Coerces the other Color object into RGB.
  def coerce(other)
    other.to_rgb
  end

  # Creates an RGB colour object from the standard range 0..255.
  #
  #   Color::RGB.new(32, 64, 128)
  #   Color::RGB.new(0x20, 0x40, 0x80)
  def initialize(r = 0, g = 0, b = 0, radix = 255.0, &block) # :yields self:
    @r, @g, @b = [ r, g, b ].map { |v| Color.normalize(v / radix) }
    block.call(self) if block
  end

  # Present the colour as a DeviceRGB fill colour string for PDF. This will
  # be removed from the default package in color-tools 2.0.
  def pdf_fill
    PDF_FORMAT_STR % [ @r, @g, @b, "rg" ]
  end

  # Present the colour as a DeviceRGB stroke colour string for PDF. This
  # will be removed from the default package in color-tools 2.0.
  def pdf_stroke
    PDF_FORMAT_STR % [ @r, @g, @b, "RG" ]
  end

  # Present the colour as an RGB hex triplet.
  def hex
    r = (@r * 255).round
    r = 255 if r > 255

    g = (@g * 255).round
    g = 255 if g > 255

    b = (@b * 255).round
    b = 255 if b > 255

    "%02x%02x%02x" % [ r, g, b ]
  end

  # Present the colour as an HTML/CSS colour string.
  def html
    "##{hex}"
  end

  # Present the colour as an RGB HTML/CSS colour string (e.g., "rgb(0%, 50%,
  # 100%)"). Note that this will perform a #to_rgb operation using the
  # default conversion formula.
  def css_rgb
    "rgb(%3.2f%%, %3.2f%%, %3.2f%%)" % [ red_p, green_p, blue_p ]
  end

  # Present the colour as an RGBA (with alpha) HTML/CSS colour string (e.g.,
  # "rgb(0%, 50%, 100%, 1)"). Note that this will perform a #to_rgb
  # operation using the default conversion formula.
  def css_rgba
    "rgba(%3.2f%%, %3.2f%%, %3.2f%%, %3.2f)" % [ red_p, green_p, blue_p, 1 ]
  end

  # Present the colour as an HSL HTML/CSS colour string (e.g., "hsl(180,
  # 25%, 35%)"). Note that this will perform a #to_hsl operation using the
  # default conversion formula.
  def css_hsl
    to_hsl.css_hsl
  end

  # Present the colour as an HSLA (with alpha) HTML/CSS colour string (e.g.,
  # "hsla(180, 25%, 35%, 1)"). Note that this will perform a #to_hsl
  # operation using the default conversion formula.
  def css_hsla
    to_hsl.css_hsla
  end

  # Converts the RGB colour to CMYK. Most colour experts strongly suggest
  # that this is not a good idea (some even suggesting that it's a very bad
  # idea). CMYK represents additive percentages of inks on white paper,
  # whereas RGB represents mixed colour intensities on a black screen.
  #
  # However, the colour conversion can be done. The basic method is
  # multi-step:
  #
  # 1. Convert the R, G, and B components to C, M, and Y components.
  #     c = 1.0 - r
  #     m = 1.0 - g
  #     y = 1.0 - b
  # 2. Compute the minimum amount of black (K) required to smooth the colour
  #    in inks.
  #     k = min(c, m, y)
  # 3. Perform undercolour removal on the C, M, and Y components of the
  #    colours because less of each colour is needed for each bit of black.
  #    Also, regenerate the black (K) based on the undercolour removal so
  #    that the colour is more accurately represented in ink.
  #     c = min(1.0, max(0.0, c - UCR(k)))
  #     m = min(1.0, max(0.0, m - UCR(k)))
  #     y = min(1.0, max(0.0, y - UCR(k)))
  #     k = min(1.0, max(0.0, BG(k)))
  #
  # The undercolour removal function and the black generation functions
  # return a value based on the brightness of the RGB colour.
  def to_cmyk
    c = 1.0 - @r.to_f
    m = 1.0 - @g.to_f
    y = 1.0 - @b.to_f

    k = [c, m, y].min
    k = k - (k * brightness)

    c = [1.0, [0.0, c - k].max].min
    m = [1.0, [0.0, m - k].max].min
    y = [1.0, [0.0, y - k].max].min
    k = [1.0, [0.0, k].max].min

    Color::CMYK.from_fraction(c, m, y, k)
  end

  def to_rgb(ignored = nil)
    self
  end

  # Returns the YIQ (NTSC) colour encoding of the RGB value.
  def to_yiq
    y = (@r * 0.299) + (@g *  0.587) + (@b *  0.114)
    i = (@r * 0.596) + (@g * -0.275) + (@b * -0.321)
    q = (@r * 0.212) + (@g * -0.523) + (@b *  0.311)
    Color::YIQ.from_fraction(y, i, q)
  end

  # Returns the HSL colour encoding of the RGB value. The conversions here
  # are based on forumlas from http://www.easyrgb.com/math.php and
  # elsewhere.
  def to_hsl
    min   = [ @r, @g, @b ].min
    max   = [ @r, @g, @b ].max
    delta = (max - min).to_f

    lum   = (max + min) / 2.0

    if Color.near_zero?(delta) # close to 0.0, so it's a grey
      hue = 0
      sat = 0
    else
      if Color.near_zero_or_less?(lum - 0.5)
        sat = delta / (max + min).to_f
      else
        sat = delta / (2 - max - min).to_f
      end

      # This is based on the conversion algorithm from
      # http://en.wikipedia.org/wiki/HSV_color_space#Conversion_from_RGB_to_HSL_or_HSV
      # Contributed by Adam Johnson
      sixth = 1 / 6.0
      if @r == max # Color.near_zero_or_less?(@r - max)
        hue = (sixth * ((@g - @b) / delta))
        hue += 1.0 if @g < @b
      elsif @g == max # Color.near_zero_or_less(@g - max)
        hue = (sixth * ((@b - @r) / delta)) + (1.0 / 3.0)
      elsif @b == max # Color.near_zero_or_less?(@b - max)
        hue = (sixth * ((@r - @g) / delta)) + (2.0 / 3.0)
      end

      hue += 1 if hue < 0
      hue -= 1 if hue > 1
    end
    Color::HSL.from_fraction(hue, sat, lum)
  end

  # Returns the XYZ colour encoding of the value. Based on the
  # {RGB to XYZ}[http://www.brucelindbloom.com/index.html?Eqn_RGB_to_XYZ.html]
  # formula presented by Bruce Lindbloom.
  #
  # Currently only the sRGB colour space is supported.
  def to_xyz(color_space = :sRGB)
    unless color_space.to_s.downcase == 'srgb'
      raise ArgumentError, "Unsupported colour space #{color_space}."
    end

    # Inverse sRGB companding. Linearizes RGB channels with respect to
    # energy.
    r, g, b = [ @r, @g, @b ].map { |v|
      100 * if (v > 0.04045)
        (((v + 0.055) / 1.055) ** 2.4)
      else
        (v / 12.92)
      end
    }

    # Convert using the RGB/XYZ matrix at:
    # http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html#WSMatrices
    Color::XYZ.new(
      r * 0.4124564 + g * 0.3575761 + b * 0.1804375,
      r * 0.2126729 + g * 0.7151522 + b * 0.0721750,
      r * 0.0193339 + g * 0.1191920 + b * 0.9503041)
  end

  # Returns the L*a*b* colour encoding of the value via the XYZ colour
  # encoding. Based on the
  # {XYZ to Lab}[http://www.brucelindbloom.com/index.html?Eqn_XYZ_to_Lab.html]
  # formula presented by Bruce Lindbloom.
  #
  # Currently only the sRGB colour space is supported and defaults to using
  # a D65 reference white.
  def to_lab(color_space = :sRGB, reference_white = Color::XYZ.d65_reference_white)
    to_xyz(color_space).to_lab(reference_white)
  end

  def to_s
    "rgb(#{@r}, #{@g}, #{@b})"
  end

  # Mix the RGB hue with White so that the RGB hue is the specified
  # percentage of the resulting colour. Strictly speaking, this isn't a
  # darken_by operation.
  def lighten_by(percent)
    mix_with(White, percent)
  end

  # Mix the RGB hue with Black so that the RGB hue is the specified
  # percentage of the resulting colour. Strictly speaking, this isn't a
  # darken_by operation.
  def darken_by(percent)
    mix_with(Black, percent)
  end

  # Mix the mask colour (which must be an RGB object) with the current
  # colour at the stated opacity percentage (0..100).
  def mix_with(mask, opacity)
    opacity /= 100.0
    rgb = self.dup

    rgb.r = (@r * opacity) + (mask.r * (1 - opacity))
    rgb.g = (@g * opacity) + (mask.g * (1 - opacity))
    rgb.b = (@b * opacity) + (mask.b * (1 - opacity))

    rgb
  end

  # Returns the brightness value for a colour, a number between 0..1. Based
  # on the Y value of YIQ encoding, representing luminosity, or perceived
  # brightness.
  #
  # This may be modified in a future version of color-tools to use the
  # luminosity value of HSL.
  def brightness
    to_yiq.y
  end
  # Convert to grayscale.
  def to_grayscale
    Color::GrayScale.from_fraction(to_hsl.l)
  end
  alias_method :to_greyscale, :to_grayscale

  # Returns a new colour with the brightness adjusted by the specified
  # percentage. Negative percentages will darken the colour; positive
  # percentages will brighten the colour.
  #
  #   Color::RGB::DarkBlue.adjust_brightness(10)
  #   Color::RGB::DarkBlue.adjust_brightness(-10)
  def adjust_brightness(percent)
    percent = normalize_percent(percent)
    hsl      = to_hsl
    hsl.l   *= percent
    hsl.to_rgb
  end

  # Returns a new colour with the saturation adjusted by the specified
  # percentage. Negative percentages will reduce the saturation; positive
  # percentages will increase the saturation.
  #
  #   Color::RGB::DarkBlue.adjust_saturation(10)
  #   Color::RGB::DarkBlue.adjust_saturation(-10)
  def adjust_saturation(percent)
    percent = normalize_percent(percent)
    hsl      = to_hsl
    hsl.s   *= percent
    hsl.to_rgb
  end

  # Returns a new colour with the hue adjusted by the specified percentage.
  # Negative percentages will reduce the hue; positive percentages will
  # increase the hue.
  #
  #   Color::RGB::DarkBlue.adjust_hue(10)
  #   Color::RGB::DarkBlue.adjust_hue(-10)
  def adjust_hue(percent)
    percent = normalize_percent(percent)
    hsl      = to_hsl
    hsl.h   *= percent
    hsl.to_rgb
  end

  # TODO: Identify the base colour profile used for L*a*b* and XYZ
  # conversions.

  # Calculates and returns the closest match to this colour from a list of
  # provided colours. Returns +nil+ if +color_list+ is empty or if there is
  # no colour within the +threshold_distance+.
  #
  # +threshold_distance+ is used to determine the minimum colour distance
  # permitted. Uses the CIE Delta E 1994 algorithm (CIE94) to find near
  # matches based on perceived visual colour. The default value (1000.0) is
  # an arbitrarily large number. The values <tt>:jnd</tt> and
  # <tt>:just_noticeable</tt> may be passed as the +threshold_distance+ to
  # use the value <tt>2.3</tt>.
  def closest_match(color_list, threshold_distance = 1000.0)
    color_list = [ color_list ].flatten(1)
    return nil if color_list.empty?

    threshold_distance = case threshold_distance
                         when :jnd, :just_noticeable
                           2.3
                         else
                           threshold_distance.to_f
                         end
    lab = to_lab
    closest_distance = threshold_distance
    best_match = nil

    color_list.each do |c|
      distance = Color::LAB.delta_e94(lab, c.to_lab)
      if (distance < closest_distance)
        closest_distance = distance
        best_match = c
      end
    end
    best_match
  end

  # Returns the red component of the colour in the normal 0 .. 255 range.
  def red
    @r * 255.0
  end
  # Returns the red component of the colour as a percentage.
  def red_p
    @r * 100.0
  end
  # Returns the red component of the colour as a fraction in the range 0.0
  # .. 1.0.
  def r
    @r
  end
  # Sets the red component of the colour in the normal 0 .. 255 range.
  def red=(rr)
    @r = Color.normalize(rr / 255.0)
  end
  # Sets the red component of the colour as a percentage.
  def red_p=(rr)
    @r = Color.normalize(rr / 100.0)
  end
  # Sets the red component of the colour as a fraction in the range 0.0 ..
  # 1.0.
  def r=(rr)
    @r = Color.normalize(rr)
  end

  # Returns the green component of the colour in the normal 0 .. 255 range.
  def green
    @g * 255.0
  end
  # Returns the green component of the colour as a percentage.
  def green_p
    @g * 100.0
  end
  # Returns the green component of the colour as a fraction in the range 0.0
  # .. 1.0.
  def g
    @g
  end
  # Sets the green component of the colour in the normal 0 .. 255 range.
  def green=(gg)
    @g = Color.normalize(gg / 255.0)
  end
  # Sets the green component of the colour as a percentage.
  def green_p=(gg)
    @g = Color.normalize(gg / 100.0)
  end
  # Sets the green component of the colour as a fraction in the range 0.0 ..
  # 1.0.
  def g=(gg)
    @g = Color.normalize(gg)
  end

  # Returns the blue component of the colour in the normal 0 .. 255 range.
  def blue
    @b * 255.0
  end
  # Returns the blue component of the colour as a percentage.
  def blue_p
    @b * 100.0
  end
  # Returns the blue component of the colour as a fraction in the range 0.0
  # .. 1.0.
  def b
    @b
  end
  # Sets the blue component of the colour in the normal 0 .. 255 range.
  def blue=(bb)
    @b = Color.normalize(bb / 255.0)
  end
  # Sets the blue component of the colour as a percentage.
  def blue_p=(bb)
    @b = Color.normalize(bb / 100.0)
  end
  # Sets the blue component of the colour as a fraction in the range 0.0 ..
  # 1.0.
  def b=(bb)
    @b = Color.normalize(bb)
  end

  # Adds another colour to the current colour. The other colour will be
  # converted to RGB before addition. This conversion depends upon a #to_rgb
  # method on the other colour.
  #
  # The addition is done using the RGB Accessor methods to ensure a valid
  # colour in the result.
  def +(other)
    self.class.from_fraction(r + other.r, g + other.g, b + other.b)
  end

  # Subtracts another colour to the current colour. The other colour will be
  # converted to RGB before subtraction. This conversion depends upon a
  # #to_rgb method on the other colour.
  #
  # The subtraction is done using the RGB Accessor methods to ensure a valid
  # colour in the result.
  def -(other)
    self + (-other)
  end

  # Retrieve the maxmum RGB value from the current colour as a GrayScale
  # colour
  def max_rgb_as_grayscale
    Color::GrayScale.from_fraction([@r, @g, @b].max)
  end
  alias_method :max_rgb_as_greyscale, :max_rgb_as_grayscale

  def inspect
    "RGB [#{html}]"
  end

  # Return array of color components
  def to_a
    [ r, g, b ]
  end

  # Numerically negate the color. This results in a color that is only
  # usable for subtraction.
  def -@
    rgb = self.dup
    rgb.instance_variable_set(:@r, -rgb.r)
    rgb.instance_variable_set(:@g, -rgb.g)
    rgb.instance_variable_set(:@b, -rgb.b)
    rgb
  end
  private
  def normalize_percent(percent)
    percent /= 100.0
    percent += 1.0
    percent  = [ percent, 2.0 ].min
    percent  = [ 0.0, percent ].max
    percent
  end
end

class << Color::RGB
  # Creates an RGB colour object from percentages 0..100.
  #
  #   Color::RGB.from_percentage(10, 20, 30)
  def from_percentage(r = 0, g = 0, b = 0, &block)
    new(r, g, b, 100.0, &block)
  end

  # Creates an RGB colour object from fractional values 0..1.
  #
  #   Color::RGB.from_fraction(.3, .2, .1)
  def from_fraction(r = 0.0, g = 0.0, b = 0.0, &block)
    new(r, g, b, 1.0, &block)
  end

  # Creates an RGB colour object from a grayscale fractional value 0..1.
  def from_grayscale_fraction(l = 0.0, &block)
    new(l, l, l, 1.0, &block)
  end
  alias_method :from_greyscale_fraction, :from_grayscale_fraction

  # Creates an RGB colour object from an HTML colour descriptor (e.g.,
  # <tt>"fed"</tt> or <tt>"#cabbed;"</tt>.
  #
  #   Color::RGB.from_html("fed")
  #   Color::RGB.from_html("#fed")
  #   Color::RGB.from_html("#cabbed")
  #   Color::RGB.from_html("cabbed")
  def from_html(html_colour, &block)
    # When we can move to 1.9+ only, this will be \h
    h = html_colour.scan(/[0-9a-f]/i)
    case h.size
    when 3
      new(*h.map { |v| (v * 2).to_i(16) }, &block)
    when 6
      new(*h.each_slice(2).map { |v| v.join.to_i(16) }, &block)
    else
      raise ArgumentError, "Not a supported HTML colour type."
    end
  end

  # Find or create a colour by an HTML hex code. This differs from the
  # #from_html method in that if the colour code matches a named colour,
  # the existing colour will be returned.
  #
  #     Color::RGB.by_hex('ff0000').name # => 'red'
  #     Color::RGB.by_hex('ff0001').name # => nil
  #
  # If a block is provided, the value that is returned by the block will
  # be returned instead of the exception caused by an error in providing a
  # correct hex format.
  def by_hex(hex, &block)
    __by_hex.fetch(html_hexify(hex)) { from_html(hex) }
  rescue
    if block
      block.call
    else
      raise
    end
  end

  # Return a colour as identified by the colour name.
  def by_name(name, &block)
    __by_name.fetch(name.to_s.downcase, &block)
  end

  # Return a colour as identified by the colour name, or by hex.
  def by_css(name_or_hex, &block)
    by_name(name_or_hex) { by_hex(name_or_hex, &block) }
  end

  # Extract named or hex colours from the provided text.
  def extract_colors(text, mode = :both)
    text  = text.downcase
    regex = case mode
            when :name
              Regexp.union(__by_name.keys)
            when :hex
              Regexp.union(__by_hex.keys)
            when :both
              Regexp.union(__by_hex.keys + __by_name.keys)
            end

    text.scan(regex).map { |match|
      case mode
      when :name
        by_name(match)
      when :hex
        by_hex(match)
      when :both
        by_css(match)
      end
    }
  end
end

class << Color::RGB
  private
  def __named_color(mod, rgb, *names)
    if names.any? { |n| mod.const_defined? n }
      raise ArgumentError, "#{names.join(', ')} already defined in #{mod}"
    end
    names.each { |n| mod.const_set(n, rgb) }
    rgb.names = names
    rgb.names.each { |n| __by_name[n] = rgb }
    __by_hex[rgb.hex] = rgb
    rgb.freeze
  end

  def __by_hex
    @__by_hex ||= {}
  end

  def __by_name
    @__by_name ||= {}
  end

  def html_hexify(hex)
    # When we can move to 1.9+ only, this will be \h
    h = hex.to_s.downcase.scan(/[0-9a-f]/)
    case h.size
    when 3
      h.map { |v| (v * 2) }.join
    when 6
      h.join
    else
      raise ArgumentError, "Not a supported HTML colour type."
    end
  end

end

require 'color/rgb/colors'
require 'color/rgb/metallic'
require 'color/rgb/contrast'
