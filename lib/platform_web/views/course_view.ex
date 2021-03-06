defmodule PlatformWeb.CourseView do
  use PlatformWeb, :view
  import PlatformWeb.ViewHelper
  import PlatformWeb.LessonView, only: [progressbar: 1]

  alias Platform.Core.Schema.CourseLesson
  alias Platform.Core.Schema.Course

  def page("index.html", conn),
    do: %{
      title: "Courses",
      path: course_path(conn, :index)
    }

  def page("new.html", conn),
    do: %{
      parent: page("index.html", conn),
      title: "New course"
    }

  def page("show.html", conn),
    do: %{
      parent: page("index.html", conn),
      title: "#{conn.assigns.course.name}"
    }

  def page("edit.html", conn),
    do: %{
      parent: page("index.html", conn),
      title: "Edit course"
    }
end
