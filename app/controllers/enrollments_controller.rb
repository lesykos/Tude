class EnrollmentsController < ApplicationController

  def create
    course = Course.find(params[:enrollment][:course_id])
    current_user.enroll!(course.id)
    redirect_to article_path(course.articles.first)
  end

  def destroy
    @course_enr = Enrollments.find(params[:id]).user
    current_user.disenroll!(@course_enr.id)
    respond_to do |format|
      format.html { redirect_to @course_enr }
      format.js
    end
  end
end