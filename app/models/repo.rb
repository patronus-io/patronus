class Repo < ActiveRecord::Base
  has_many :reviewerships
  has_many :users, through: :reviewerships
  has_many :port_branches

  def to_s
    name
  end
end
