defmodule Platform.Core.LessonSync do
  @moduledoc """
  Keeps database and online lesson in sync
  """
  alias Platform.Repo
  alias Platform.GoogleSlides
  alias Platform.Core.Schema.Lesson
  alias Platform.Core.Schema.Slide
  require Ecto.Query

  def sync_slides(%Lesson{} = lesson) do
    google_presentation = GoogleSlides.get_presentation!(lesson.google_presentation_id)

    sync_slides(google_presentation)
  end
  def sync_slides(%GoogleApi.Slides.V1.Model.Presentation{} = google_presentation) do
    lesson = get_lesson_by_google_presentation_id!(google_presentation.presentationId)
    #content = inspect google_presentation = GoogleSlides.get_presentation!(lesson.google_presentation_id)
    #File.write!("response.exs", content)

    delete_removed_slides(lesson, google_presentation.slides)
    create_or_update_slides(lesson, google_presentation.slides)
  end

  def create_or_update_slides(%Lesson{} = lesson, google_slides) when is_list(google_slides) do
    index_google_slides = Enum.with_index google_slides

    Enum.each index_google_slides, fn({google_slide, index}) ->
      google_object_id = google_slide.objectId

      changes = %{
        position: index,
        name: Platform.GoogleSlides.get_title(google_slide),
        speaker_notes: GoogleSlides.get_speaker_notes(google_slide),
        speaker_notes_hash: GoogleSlides.generate_hash_for_speakernotes(google_slide),
        page_elements_hash: GoogleSlides.generate_hash_for_page_elements(google_slide),
        synced_at: DateTime.utc_now
      }

      slide = case Repo.get_by(Slide, lesson_id: lesson.id, google_object_id: google_object_id) do
        nil  -> %Slide{lesson_id: lesson.id, google_object_id: google_object_id}
        slide -> slide          # Post exists, let's use it
      end

      slide
      |> Slide.changeset(changes)
      |> Repo.insert_or_update!
    end
  end

  def update_hash_for_slide(%Slide{} = slide, google_slide) do
    changes = %{
      speaker_notes: GoogleSlides.get_speaker_notes(google_slide),
      speaker_notes_hash: GoogleSlides.generate_hash_for_speakernotes(google_slide),
      page_elements_hash: GoogleSlides.generate_hash_for_page_elements(google_slide),
      synced_at: DateTime.utc_now
    }

    slide
    |> Slide.changeset(changes)
    |> Repo.update!
  end

  def delete_removed_slides(%Lesson{} = lesson, google_slides) when is_list(google_slides) do
    slide_ids = Enum.map(google_slides, fn(google_slide) -> google_slide.objectId end)

    # delete slides that have been deleted online
    slides =
      lesson
      |> Ecto.assoc(:slides)
      |> Ecto.Query.where([c], not c.google_object_id in ^slide_ids)
      |> Repo.all()

    Enum.each slides, fn slide ->
      Repo.delete(slide)
    end
  end

  def get_lesson_by_google_presentation_id!(id) do
    Repo.get_by!(Lesson, google_presentation_id: id)
  end
end
