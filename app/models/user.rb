class User < ActiveRecord::Base
  has_many :repos
end
