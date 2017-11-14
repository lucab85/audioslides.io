defmodule Platform.Video do
  @moduledoc """
  Context for the video converter
  """
  require Logger

  alias Platform.Filename
  alias Platform.GoogleSlides
  alias Platform.Speech
  alias Platform.Converter

  alias Platform.Core.Schema.Lesson
  alias Platform.Core.Schema.Slide
  alias Platform.Core.LessonSync

  def convert_lesson_to_video(%Lesson{} = lesson) do
    final_output_filename = Filename.get_filename_for_lesson_video(lesson)

    # start async creation of the videos
    video_generation_tasks = Enum.map(lesson.slides, fn(slide) -> Task.async(fn -> generate_video_for_slide(lesson, slide) end) end)

    # wait 60 seconds for all video generator processes
    tasks_with_results = Task.yield_many(video_generation_tasks, 60_000)

    generated_video_filenames = Enum.map(tasks_with_results, fn {task, res} ->
      # Shutdown the tasks that did not reply nor exit
      case res do
        {:ok, value} ->
          value
        nil ->
          Task.shutdown(task, :brutal_kill)
      end
    end)

    Converter.merge_videos(video_filename_list: generated_video_filenames, output_filename: final_output_filename)
  end

  def generate_video_for_slide(%Lesson{} = lesson, %Slide{} = slide) do

    google_slide = GoogleSlides.get_slide!(lesson.google_presentation_id, slide.google_object_id)

    image_filename = create_or_update_image_for_slide(lesson, slide, google_slide)
    audio_filename = create_or_update_audio_for_slide(lesson, slide, google_slide)

    video_filename = Filename.get_filename_for_slide_video(lesson, slide)

    # Only generate video of audio or video changed
    if !File.exists?(video_filename) || GoogleSlides.any_content_changed?(slide, google_slide) do
      Logger.info "Slide #{slide.id} Hash: updated"
      LessonSync.update_hash_for_slide(slide, google_slide)

      Logger.info "Slide #{slide.id} Video: generated"
      Converter.generate_video(
        audio_filename: audio_filename,
        image_filename: image_filename,
        output_filename: video_filename
      )
    else
      Logger.info "Slide #{slide.id} Video: skipped"
    end

    # relative_output_filename
    # "#{lesson.id}/#{slide.id}.mp4"
    Filename.get_filename_for_slide_video(lesson, slide)
  end

  def create_or_update_image_for_slide(lesson, slide, google_slide) do
    image_filename = Filename.get_filename_for_slide_image(lesson, slide)
    if !File.exists?(image_filename) || GoogleSlides.content_changed_for_page_elements?(slide, google_slide) do
      Logger.info "Slide #{slide.id} Image: generated"
      GoogleSlides.download_slide_thumb!(lesson.google_presentation_id, slide.google_object_id, image_filename)
    else
      Logger.info "Slide #{slide.id} Image: skipped"
    end

    image_filename
  end

  def create_or_update_audio_for_slide(lesson, slide, google_slide) do
    audio_filename = Filename.get_filename_for_slide_audio(lesson, slide)
    if !File.exists?(audio_filename) || GoogleSlides.content_changed_for_speaker_notes?(slide, google_slide) do
      Logger.info "Slide #{slide.id} Audio: generated"
      notes = GoogleSlides.get_speaker_notes(google_slide)

      speech_binary = Speech.speak()
      |> Speech.language(lesson.voice_language)
      |> Speech.voice_gender(lesson.voice_gender)
      |> Speech.text(notes)
      |> Speech.run()

      write_to_file(audio_filename, speech_binary)
    else
      Logger.info "Slide #{slide.id} Audio: skipped"
    end

    audio_filename
  end

  defp write_to_file(filename, data) do
    [_, directory, filename] = Regex.run(~r/^(.*\/)([^\/]*)$/, filename)
    File.mkdir_p(directory)
    {:ok, file} = File.open filename, [:write]
    IO.binwrite(file, data)
  end
end
