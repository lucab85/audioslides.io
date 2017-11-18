defmodule Platform.LessonSyncTest do
  use Platform.DataCase

  import Mock

  # alias Platform.Core.Schema.Lesson
  alias Platform.Core.LessonSync
  alias Platform.GoogleSlides
  alias Platform.GoogleSlidesFactory
  alias Platform.Factory

  setup do
    lesson = Factory.insert(:lesson)

    google_slide1 = GoogleSlidesFactory.get_base_slide(object_id: "objID_1", content: "Example Content 1", speaker_notes: "Speaker Notes 1")
    google_slide2 = GoogleSlidesFactory.get_base_slide(object_id: "objID_2", content: "Example Content 2", speaker_notes: "Speaker Notes 2")

    google_presentation = %GoogleApi.Slides.V1.Model.Presentation{
      presentationId: lesson.google_presentation_id,
      slides: [google_slide1, google_slide2]
    }
    {:ok, %{lesson: lesson, google_presentation: google_presentation}}
  end

  describe "#sync_slides" do
    test "should insert slides if they don't exist", %{lesson: lesson, google_presentation: google_presentation} do
      LessonSync.sync_slides(google_presentation)

      lesson =
        lesson
        |> Repo.preload(:slides)

      assert length(lesson.slides) == 2
      assert Enum.map(lesson.slides, fn(slide) -> slide.google_object_id end) == ["objID_1", "objID_2"]
    end

    test "should delete slides" do
      lesson = Factory.insert(:lesson)
      Factory.insert(:slide, lesson: lesson)

      slide1 = GoogleSlidesFactory.get_base_slide(object_id: "objID_1", content: "Example Content 1", speaker_notes: "Speaker Notes 1")

      google_presentation = %GoogleApi.Slides.V1.Model.Presentation{
        presentationId: lesson.google_presentation_id,
        slides: [slide1]
      }

      LessonSync.sync_slides(google_presentation)

      lesson =
        lesson
        |> Repo.preload(:slides)

      assert length(lesson.slides) == 1
      assert Enum.map(lesson.slides, fn(slide) -> slide.google_object_id end) == ["objID_1"]
    end
  end


  describe "create_or_update_slides" do
    test "should fetch a google presentation and sync with %Lesson{} as parameter", %{lesson: lesson, google_presentation: google_presentation} do
      with_mock GoogleSlides, [:passthrough], [get_presentation: fn _ -> google_presentation end] do
        LessonSync.sync_slides(lesson)

        assert called GoogleSlides.get_presentation(lesson.google_presentation_id)
      end
    end

    test "should return an error when google api fails", %{lesson: lesson} do
      with_mock GoogleSlides, [:passthrough], [get_presentation: fn _ -> {:error, %{body: "{\n  \"error\": {\n    \"code\": 403,\n    \"message\": \"A message\",\n    \"status\": \"A status\"\n  }\n}\n"}} end] do
        result = LessonSync.sync_slides(lesson)

        assert result == {:error, %{message: "A message", status: "A status"}}
      end
    end

    test "should insert slides if they don't exist with a lesson as input", %{lesson: lesson, google_presentation: google_presentation} do
      with_mock GoogleSlides, [:passthrough], [get_presentation: fn _ -> google_presentation end] do
        LessonSync.sync_slides(lesson)

        lesson =
          lesson
          |> Repo.preload(:slides)

        assert length(lesson.slides) == 2
        assert Enum.map(lesson.slides, fn(slide) -> slide.google_object_id end) == ["objID_1", "objID_2"]
      end
    end

    test "should not double-insert a slide if already exists", %{lesson: lesson, google_presentation: google_presentation} do
      with_mock GoogleSlides, [:passthrough], [get_presentation: fn _ -> google_presentation end] do
        LessonSync.sync_slides(lesson)

        lesson =
          lesson
          |> Repo.preload(:slides)

        assert length(lesson.slides) == 2
        assert Enum.map(lesson.slides, fn(slide) -> slide.google_object_id end) == ["objID_1", "objID_2"]

        LessonSync.sync_slides(lesson)

        lesson =
        lesson
        |> Repo.preload(:slides)

        assert length(lesson.slides) == 2
        assert Enum.map(lesson.slides, fn(slide) -> slide.google_object_id end) == ["objID_1", "objID_2"]
      end
    end

  end

  describe "get_error_from_response" do
    test "should return the reason of a error" do
      example_response = {:error, %{body: "{\n  \"error\": {\n    \"code\": 403,\n    \"message\": \"Request had insufficient authentication scopes.\",\n    \"status\": \"PERMISSION_DENIED\"\n  }\n}\n"}}

      error = LessonSync.get_error_from_response(example_response)

      assert error.message == "Request had insufficient authentication scopes."
      assert error.status == "PERMISSION_DENIED"

    end
  end
end
