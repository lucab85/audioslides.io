defmodule PlatformWeb.SlideControllerTest do
  use PlatformWeb.ConnCase

  setup [:create_lesson, :set_current_user_as_admin]

  describe "#show" do
    setup :create_slide

    test "renders a slide", %{conn: conn, lesson: lesson, slide: slide} do
      conn = get(conn, lesson_slide_path(conn, :show, lesson, slide))
      assert html_response(conn, 200) =~ slide.name
    end
  end

  describe "#edit" do
    setup :create_slide

    test "renders form for editing chosen slide", %{conn: conn, lesson: lesson, slide: slide} do
      conn = get(conn, lesson_slide_path(conn, :edit, lesson, slide))
      assert html_response(conn, 200) =~ slide.name
    end
  end

  describe "#generate_video" do
    setup :create_slide

    alias Platform.VideoConverter.TestAdapter

    test "renders form for editing chosen slide", %{conn: conn, lesson: lesson, slide: slide} do
      conn = post(conn, lesson_slide_path(conn, :generate_video, lesson, slide))
      assert redirected_to(conn) == lesson_slide_path(conn, :show, lesson, slide)
      assert length(TestAdapter.generate_video_list()) == 1
    end
  end

  # Private functions
  defp create_lesson(_) do
    lesson = Factory.insert(:lesson)
    {:ok, lesson: lesson}
  end

  defp create_slide(%{lesson: lesson}) do
    slide = Factory.insert(:slide, lesson: lesson, video_hash: "B")
    {:ok, slide: slide}
  end

  defp set_current_user_as_admin(%{conn: conn}) do
    user = Factory.insert(:user, admin: true)
    conn = %{conn | assigns: %{current_user: user}}
    {:ok, conn: conn}
  end
end
