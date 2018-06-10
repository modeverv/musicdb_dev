require 'bson'
require 'mongo'
require 'mongoid'

Mongoid.load!( File.dirname(__FILE__) + "/mongoid.yml",:production)

class XMid
  include Mongoid::Document
  field :mids
end


x = XMid.new()

x.mids="dddd"

x.save

