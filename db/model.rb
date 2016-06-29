class ActiveRecord::Base
  def self.required_fields(options = {})
    options[:include] ||= []
    options[:include].map!(&:to_sym)

    options[:exclude] ||= []
    options[:exclude].map!(&:to_sym)

    fields = self.validators
                 .select{|x| ActiveRecord::Validations::PresenceValidator === x }
                 .map(&:attributes)
                 .flatten
    fields - options[:exclude] + options[:include]
  end

  def self.allowed_to_create_by?(user = nil, action: "")
    return self.accessible_resources(user: user, method: "POST", action: action).any?
  end

  def self.accessible_resources(user: nil, method: , action: "")
    current_user = user

    role = if user
      user.role
    else
      Role.find_by(name: "Nologin")
    end

    p = Permission.find_by(resource: self.to_s.downcase.pluralize,
                           role: role,
                           method: method.to_s.upcase,
                           action: action)
    puts permission: p
    return self.none if p.nil?
    p.resources(binding)
  end
end

class Team < ActiveRecord::Base
  validates :name, presence: true

  has_many :members, dependent: :nullify
  has_many :answers, dependent: :destroy
  has_many :issues, dependent: :destroy
end

class Role < ActiveRecord::Base
  validates :name, presence: true
  validates :rank, presence: true

  has_many :members
  has_many :permissions
end

class Permission < ActiveRecord::Base
  validates :resource, presence: true, uniqueness: { scope: [:method, :action, :role_id] }
  validates :method,   presence: true
  validates :query,    presence: true
  validates :join,     presence: true

  belongs_to :role

  def resources(bind = nil)
    klass = resource.singularize.capitalize.constantize

    params = if parameters.nil?
      {}
    else
      eval(parameters, bind)
    end

    klass.joins(join.split(?\s).map(&:to_sym)) \
         .where(query, params)
  end
end

class Member < ActiveRecord::Base
  validates :name,            presence: true
  validates :login,           presence: true, uniqueness: true
  validates :hashed_password, presence: true
  validates :team,            presence: true, if: Proc.new {|member| not member.team_id.nil? }
  validates :role,            presence: true

  has_many :marked_scores   , foreign_key: "marker_id" , class_name: "Score"  , dependent: :destroy
  has_many :created_problems, foreign_key: "creator_id", class_name: "Problem", dependent: :destroy

  has_many :comments, dependent: :destroy
  belongs_to :team
  belongs_to :role
end

class Problem < ActiveRecord::Base
  validates :title,     presence: true
  validates :text,      presence: true
  validates :opened_at, presence: true
  validates :closed_at, presence: true
  validates :creator,   presence: true

  has_many :answers,  dependent: :destroy
  has_many :comments, dependent: :destroy, as: :commentable
  has_many :issues,   dependent: :destroy

  belongs_to :creator, foreign_key: "creator_id", class_name: "Member"
end

class Issue < ActiveRecord::Base
  validates :title,   presence: true
  validates :problem, presence: true
  validates :team, presence: true
  validates :closed, inclusion: { in: [true, false] }

  has_many :comments, dependent: :destroy, as: :commentable

  belongs_to :problem
  belongs_to :team
end

class Answer < ActiveRecord::Base
  validates :problem, presence: true
  validates :score,   presence: true, if: Proc.new {|answer| not answer.score_id.nil? }
  validates :team,    presence: true, uniqueness: { scope: :problem }

  has_many :comments, dependent: :destroy, as: :commentable

  belongs_to :problem
  belongs_to :score
  belongs_to :team
end

class Score < ActiveRecord::Base
  validates :point,  presence: true
  validates :answer, presence: true
  validates :marker, presence: true

  belongs_to :answer
  belongs_to :marker, foreign_key: "marker_id", class_name: "Member"
end

class Comment < ActiveRecord::Base
  validates :text,    presence: true
  validates :member,  presence: true
  validates :commentable, presence: true

  belongs_to :member
  belongs_to :commentable, polymorphic: true

  private
    def commentable_type_check
      return if commentable_type.nil?
      unless %w(Problem Issue Answer).include? commentable_type
        errors.add(:commentable, "specify one of problems, issues or answers")
      end
    end
end
