defmodule Platform.GoogleSlidesAPI do
  @moduledoc """
  The google slides context
  """

  alias Goth.Token
  alias GoogleApi.Slides.V1.Api.Presentations
  alias GoogleApi.Slides.V1.Connection
  alias FileHelper

  @behaviour Platform.SlideAPI

  def get_presentation(presentation_id) when is_binary(presentation_id) do
    connection = get_google_slides_connection!()

    Presentations.slides_presentations_get(
      connection,
      presentation_id,
      fields: "presentationId,title,slides"
    )
  end

  def get_slide!(presentation_id, slide_id) do
    connection = get_google_slides_connection!()

    {:ok, slide_page} = Presentations.slides_presentations_pages_get(connection, presentation_id, slide_id)

    slide_page
  end

  def get_slide_thumb!(presentation_id, slide_id) do
    connection = get_google_slides_connection!()

    {:ok, slide_page_thumb} =
      Presentations.slides_presentations_pages_get_thumbnail(
        connection,
        presentation_id,
        slide_id
      )

    slide_page_thumb
  end

  def download_slide_thumb!(presentation_id, slide_id, filename) do
    slide_page_thumb = get_slide_thumb!(presentation_id, slide_id)
    url = slide_page_thumb.contentUrl

    %HTTPoison.Response{body: body} = HTTPoison.get!(url)

    FileHelper.write_to_file(filename, body)
    filename
  end

  def update_speaker_notes!(presentation_id, slide_id, text) do
    slide_page = get_slide!(presentation_id, slide_id)
    speaker_notes_object_id = slide_page.slideProperties.notesPage.notesProperties.speakerNotesObjectId

    body = %{
      requests: [
        %{
          deleteText: %{
            objectId: speaker_notes_object_id,
            textRange: %{
              type: "ALL"
            }
          }
        },
        %{
          insertText: %{
            objectId: speaker_notes_object_id,
            insertionIndex: 0,
            text: text
          }
        }
      ]
    }

    connection = get_google_slides_connection!()
    Presentations.slides_presentations_batch_update(connection, presentation_id, body: Poison.encode!(body))
  end

  # Private functions
  defp get_google_slides_connection! do
    scopes = [
      "https://www.googleapis.com/auth/presentations"
    ]

    {:ok, goth_token} = Token.for_scope(Enum.join(scopes, " "))

    Connection.new(goth_token.token)
  end
end
