class Role < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  validates :rank, presence: true

  has_many :members

  # method: POST
  def self.allowed_to_create_by?(user = nil, action: "")
    case user&.role_id
    when ROLE_ID[:admin]
      true
    else # nologin, ...
      false
    end
  end

  # method: GET, PUT, PATCH, DELETE
  def allowed?(method:, by: nil, action: "")
    return self.class.readables(user: by, action: action).exists?(id: id) if method == "GET"

    case by&.role_id
    when ROLE_ID[:admin]
      true
    else # nologin, ...
      false
    end
  end

  # method: GET
  scope :readables, ->(user: nil, action: "") {
    case user&.role_id
    when ROLE_ID[:admin]
      all
    when ROLE_ID[:writer]
      where("rank >= ?", user.role.rank)
    when nil # nologin
      where("id = ?", ROLE_ID[:participant])
    else # nologin, ...
      none
    end
  }
end
