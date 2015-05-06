require 'babosa'
class Course < ActiveRecord::Base

  LEVELS = ['easy', 'middle', 'hard']

  belongs_to :author, class_name: "User", foreign_key: 'user_id'
  belongs_to :category, counter_cache: true
  has_many :sections, -> { order(position: :asc) }
  has_many :articles, through: :sections
  has_many :different_articles, through: :sections, source: :different_articles
  has_many :reviews, -> { published }
  has_many :enrollments
  has_many :users, through: :enrollments
  has_many :views, as: :viewable

  validates :slug, presence: true
  validates :level, inclusion: {in: LEVELS, message: "must be: easy/middle/hard"}

  after_touch :update_duration

  extend FriendlyId
  friendly_id :title, use: :slugged

  delegate :name, to: :category, prefix: true, allow_nil: true
  delegate :name, :whois, to: :author, prefix: true, allow_nil: true

  scope :order_popular, -> { order(views_count: :desc) }

  # OPTIMIZE
  def user_progress(user, return_type = "sizes")
    course_articles_ids_array = self.course_articles_ids
    passed_articles_ids_array = user.passed_articles_ids
    passed_course_articles_ids = course_articles_ids_array & passed_articles_ids_array
    if return_type == "sizes"
      passed = passed_course_articles_ids.size
      all = course_articles_ids_array.size
      [passed, all]
    elsif return_type == "passed"
      passed_course_articles_ids
    elsif return_type == "progress"
      passed = passed_course_articles_ids.size
      all = course_articles_ids_array.size
      ( ( passed.to_f / all.to_f ) * 100 ).ceil
    end
  end

  def continue_course_article(user)
    course_articles_ids_array = self.course_articles_ids
    passed_articles_ids_array = user.passed_articles_ids
    not_completed_articles_ids = course_articles_ids_array - passed_articles_ids_array
    if not_completed_articles_ids.any?
      Article.friendly.find(not_completed_articles_ids[0])
    else
      self.articles.first
    end
  end

  def course_articles_ids
    self.articles.ids
  end

  def normalize_friendly_id(string)
    string.to_s.to_slug.normalize(transliterations: :ukrainian).to_s
  end

 private

  def update_duration
    self.duration = self.sections.sum(:duration)
    self.save!
  end
end
