module PJSON
  class Context
    def initialize(s)
      @buf = s
      @index = 0
      @length = s.size
    end
    def skip_white
      while [" ", "\t", "\r", "\n"].include? @buf[@index] do
        @index += 1
      end 
    end
    def has_next?
      @index < @length
    end
    def next
      b = @buf[@index]
      @index += 1
      b
    end
    def back
      @index -= 1
    end
    def current
      return @buf[@index]
    end
    def error(msg)
      raise "#{msg}: #{@buf[@index...-1]}"
    end
    def parse_constant
      s = ''
      pos = @index
      while self.has_next?
        c = self.next
        unless 'truefalsenull'.include? c
          self.back
          break
        end
        s += c
        case s
        when 'true'
          return true
        when 'false'
          return false
        when 'null'
          return nil
        end
      end
      @index = pos
      error 'Unknown token'
    end
    def parse_number
      s = self.next
      while self.has_next?
        c = self.next
        unless '0123456789+-.eE'.include? c
          self.back
          break
        end
        s += c
      end
      if s.include? '.'
        return s.to_f
      end
      return s.to_i
    end
    def parse_string
      self.next
      s = ''
      while self.has_next?
        c = self.next
        case c
        when '\\'
          c = self.next
          case c
          when '\\', '/'
            s += c
          when 'b'
            s += "\b"
          when 'f'
            s += "\f"
          when 'n'
            s += "\n"
          when 'r'
            s += "\r"
          when 't'
            s += "\t"
          when 'u'
            u = 0
            while self.has_next?
              c = self.next
              i = '0123456789abcdef'.index(c.downcase)
              if i == nil
                self.back
                break
              end
              u = u * 16 | i
            end
            if u < 0x80
              s += u.chr
            elsif u < 0x800
              s += (0xc0 | (u >> 6)).chr
              s += (0x80 + (u & 0x3f)).chr
            elsif u < 0x10000
              s += (0xe0 | (u >> 12)).chr
              s += (0x80 | ((u >> 6) & 0x3f)).chr
              s += (0x80 | (u & 0x3f)).chr
            elsif u < 0x200000
              s += (0xf0 | (u >> 18)).chr
              s += (0x80 | ((u >> 12) & 0x3f)).chr
              s += (0x80 | ((u >> 6) & 0x3f)).chr
              s += (0x80 | (u & 0x3f)).chr
            elsif u < 0x4000000
              s += (0xf8 | (u >> 24)).chr
              s += (0x80 | ((u >> 18) & 0x3f)).chr
              s += (0x80 | ((u >> 12) & 0x3f)).chr
              s += (0x80 | ((u >> 6) & 0x3f)).chr
              s += (0x80 | (u & 0x3f)).chr
            else
              s += (0xfc | (u >> 30)).chr
              s += (0x80 | ((u >> 24) & 0x3f)).chr
              s += (0x80 | ((u >> 18) & 0x3f)).chr
              s += (0x80 | ((u >> 12) & 0x3f)).chr
              s += (0x80 | ((u >> 6) & 0x3f)).chr
              s += (0x80 | (u & 0x3f)).chr
            end
          else
            error 'Invalid string token'
          end
        when '"'
          return s
        else
          s += c
        end
      end
      error 'Invalid string token'
    end
    def parse_object
      self.next
      o = {}
      while self.has_next?
        self.skip_white
        c = self.next
        if c == '}'
          break
        end
        if c != '"'
          error 'Expected "\"" but not found'
        end
        self.back
        k = self.parse_string
        self.skip_white
        c = self.next
        if c != ':'
          error 'Expected ":" but not found'
        end
        self.skip_white
        v = self.parse_value
        o[k] = v
        self.skip_white
        c = self.next
        if c == '}'
          break
        end
        if c != ','
          error 'Expected "," or "}" but not found'
        end
      end
      o
    end
    def parse_array
      self.next
      a = []
      while self.has_next?
        self.skip_white
        if self.current == ']'
          break
        end
        i = self.parse_value
        self.skip_white
        c = self.next
        a << i
        if c == ']'
          break
        end
        if c != ','
          error 'Expected "," or "]" but not found'
        end
      end
      a
    end
    def parse_value
      while self.has_next?
        self.skip_white
        c = self.current
        case c
        when '{'
          return self.parse_object
        when '['
          return self.parse_array
        when '"'
          return self.parse_string
        when '0','1','2','3','4','5','6','7','8','9','-'
          return self.parse_number
        when 't', 'f', 'n'
          return self.parse_constant
        else
          error 'Invalid sequence'
        end
      end
    end
  end
  def self.parse(text)
    PJSON::Context.new(text).parse_value
  end
end