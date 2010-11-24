
require 'rubygems'
require 'active_record'
require 'kconv'

ActiveRecord::Base.establish_connection(:adapter => "mysql", :host => "localhost", :username => "root", :password => "", :database => "copper")

ActiveRecord::Base.table_name_prefix = "cpg_"

class Usergroup < ActiveRecord::Base
  has_many :users, :primary_key => "group_id", :foreign_key => "user_group"
  has_many :visible_albums, :class_name => "Album", :primary_key => "group_id", :foreign_key => "visibility"
end

class User < ActiveRecord::Base
  has_many :pictures, :primary_key => "user_id", :foreign_key => "owner_id"
  belongs_to :usergroup, :primary_key => "group_id", :foreign_key => "user_group"
end

class Picture < ActiveRecord::Base
  belongs_to :album, :primary_key => "aid", :foreign_key => "aid"
end

class Album < ActiveRecord::Base
  belongs_to :category, :primary_key => "cid", :foreign_key => "category"
  has_many :pictures, :primary_key => "aid", :foreign_key => "aid"
  belongs_to :allowed_group, :class_name => "Usergroup", :primary_key => "group_id", :foreign_key => "visibility"
end

class Category < ActiveRecord::Base
  has_many :albums, :primary_key => "cid", :foreign_key => "category"
end

# class  < ActiveRecord::Base
# end
