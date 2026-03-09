defmodule A2UI.Components.MediaTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Video component" do
    test "renders video tag with CSS class" do
      component = make_component("vid", "Video", %{"url" => "https://example.com/movie.mp4"})
      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<video"
      assert html =~ "a2ui-video"
      assert html =~ ~s(src="https://example.com/movie.mp4")
    end

    test "resolves data-bound url" do
      component = make_component("vid", "Video", %{"url" => %{"path" => "/video_url"}})

      ctx =
        make_ctx(%{"vid" => component}, "s1",
          data: %{"video_url" => "https://bound.com/clip.mp4"}
        )

      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(src="https://bound.com/clip.mp4")
    end

    test "controls defaults to true" do
      component = make_component("vid", "Video", %{"url" => "movie.mp4"})
      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "controls"
    end

    test "controls false omits the attribute" do
      component = make_component("vid", "Video", %{"url" => "movie.mp4", "controls" => false})
      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "controls"
    end

    test "autoplay attribute when true" do
      component =
        make_component("vid", "Video", %{"url" => "movie.mp4", "autoplay" => true})

      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "autoplay"
    end

    test "autoplay defaults to false" do
      component = make_component("vid", "Video", %{"url" => "movie.mp4"})
      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "autoplay"
    end

    test "renders accessibility attributes" do
      component =
        make_component("vid", "Video", %{"url" => "movie.mp4"},
          accessibility: %{"label" => "Demo video", "role" => "presentation"}
        )

      ctx = make_ctx(%{"vid" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(aria-label="Demo video")
      assert html =~ ~s(role="presentation")
    end
  end

  describe "AudioPlayer component" do
    test "renders audio tag with CSS class" do
      component =
        make_component("aud", "AudioPlayer", %{"url" => "https://example.com/song.mp3"})

      ctx = make_ctx(%{"aud" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<audio"
      assert html =~ "a2ui-audio-player"
      assert html =~ ~s(src="https://example.com/song.mp3")
    end

    test "resolves data-bound url" do
      component = make_component("aud", "AudioPlayer", %{"url" => %{"path" => "/audio_url"}})

      ctx =
        make_ctx(%{"aud" => component}, "s1",
          data: %{"audio_url" => "https://bound.com/track.mp3"}
        )

      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(src="https://bound.com/track.mp3")
    end

    test "controls defaults to true" do
      component = make_component("aud", "AudioPlayer", %{"url" => "song.mp3"})
      ctx = make_ctx(%{"aud" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "controls"
    end

    test "controls false omits the attribute" do
      component =
        make_component("aud", "AudioPlayer", %{"url" => "song.mp3", "controls" => false})

      ctx = make_ctx(%{"aud" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "controls"
    end

    test "renders accessibility attributes" do
      component =
        make_component("aud", "AudioPlayer", %{"url" => "song.mp3"},
          accessibility: %{"label" => "Background music"}
        )

      ctx = make_ctx(%{"aud" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(aria-label="Background music")
    end
  end
end
