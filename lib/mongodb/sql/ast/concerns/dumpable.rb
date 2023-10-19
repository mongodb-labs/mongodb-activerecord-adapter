# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      module Dumpable
        module ClassMethods
          def dumpable(*attrs)
            attr_reader(*attrs)
            @dump_attrs = attrs
          end

          def dump(obj, depth)
            label = self.name.to_s.split(/::/).last
            indent = '  ' * depth
            puts "#{indent}#{label}"
            @dump_attrs.each do |attr|
              dump_value(attr, obj.send(attr), depth + 1)
            end
          end

          def dump_value(prefix, value, depth)
            indent = '  ' * depth
            print "#{indent}#{prefix}"

            case value
            when Dumpable
              puts
              value.dump(depth + 1)
            when Array
              puts
              value.each do |item|
                dump_value('- ', item, depth + 1)
              end
            else
              puts ": #{value.inspect}"
            end
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end

        def dump(depth = 0)
          self.class.dump(self, depth)
        end
      end
    end
  end
end
