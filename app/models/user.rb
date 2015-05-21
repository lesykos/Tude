class User < ActiveRecord::Base

  USERNAME_REGEX = /([A-Za-z0-9_]{3,15})/

  # Virtual attribute for authenticating by either username or email
  attr_accessor :login

  has_many :articles
  has_many :comments
  has_many :reviews
  has_many :own_courses, class_name: "Course"
  # has_many :favorites
  # has_many :favorite_articles, through: :favorites, source: :favorable, source_type: 'Article'
  has_many :enrollments
  has_many :courses, through: :enrollments
  has_many :mentions
  has_many :comments_with_mentions, through: :mentions, source: :mentionable, source_type: 'Comment'
  has_many :article_progresses, foreign_key: :student_id
  has_many :passed_articles, through: :article_progresses, source: :article
  has_many :subscriptions, foreign_key: :subscriber_id
  has_many :subscribed_articles, through: :subscriptions, source: :subscribable, source_type: 'Article'
  has_many :subscribed_courses, through: :subscriptions, source: :subscribable, source_type: 'Course'
  has_many :activities, foreign_key: :owner_id

  validates :username, presence: true, uniqueness: {case_sensitive: false},
                        exclusion: {in: %w(www edut admin), message: "%{value} is reserved"},
                        format: {with: USERNAME_REGEX, message: 'Only letters, numbers and underscore'}

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

  recommends :articles, :courses, :comments, :reviews

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions.to_h).first
    end
  end

  def name
    self.fullname.present? ? self.fullname : self.username
  end

  def to_param
    username
  end

  def enroll!(course_id)
    self.enrollments.find_or_create_by!(course_id: course_id)
    self.like(Course.find(course_id))
  end

  def enrolled?(course_id)
    self.enrollments.find_by(course_id: course_id) ? true : false
  end

  def disenroll!(course_id)
    self.enrollments.find_by(course_id: course_id).destroy!
    self.unlike(Course.find(course_id))
  end

  def wrote_review?(course_id)
    self.reviews.find_by(course_id: course_id) ? true : false
  end

  def pass_article!(article, user_progress = {})
    progress = self.article_progresses.find_or_initialize_by(article_id: article.id)
    if progress.new_record?
      progress.save!
      self.complete_enrollment(article.course_id, user_progress)
    end
  end

  def complete_enrollment(course_id, user_progress)
    if !user_progress.empty?
      if ( (user_progress[:passed_course_articles_ids].size + 1) == user_progress[:course_articles_ids].size )
        enrollment = Enrollment.find_by(course_id: course_id, user_id: self.id)
        enrollment.completed!
        enrollment.track_completion(self, course_id)
      end
    end
  end

  def article_passed?(article_id)
    self.article_progresses.find_by(article_id: article_id) ? true : false
  end

  def cancel_passed_article!(article_id)
    self.article_progresses.find_by(article_id: article_id).destroy!
  end

  def passed_articles_ids
    self.passed_articles.ids
  end
end
