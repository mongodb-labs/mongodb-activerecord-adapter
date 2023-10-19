# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require "active_record"

config = {
  adapter: 'mongodb',
  host: 'localhost:27017',
  database: 'demo'
}

ActiveRecord::Base.establish_connection(config)

# This is a MongoDB adapter-specific method that removes all
# collections and indexes. You should probably *not* call it in
# production...
ActiveRecord::Base.connection.purge_database!

class PrepareDemoSchema < ActiveRecord::Migration[7.1]
  def change
    create_table :people do |t|
      t.string :name, null: false
      t.integer :age
      t.timestamps
    end
  end
end

PrepareDemoSchema.migrate(:up)

class Person < ActiveRecord::Base
end

puts "Inserting people..."
Person.create!(name: 'Joe', age: 34)
Person.create!(name: 'Dorothy', age: 52)
Person.create!(name: 'Brenda', age: 18)
Person.create!(name: 'Will', age: 27)

puts
puts "Here are the records we inserted:"
Person.all.each do |person|
  puts "[#{person.id}] #{person.name}: #{person.age}"
end

puts
joe = Person.first
puts "Joe's record is #{joe.inspect}"
joe.update age: 35

puts
puts "After update, Joe is #{joe.inspect}"
puts 'Reloading Joe...'
p joe.reload
puts "Reloaded Joe is #{joe.inspect}"

puts
puts 'Deleting Joe...'
joe.delete

puts 'First record should no longer be Joe:'
p Person.first
