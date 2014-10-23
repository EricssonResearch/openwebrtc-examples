# Mac OS X examples
A simple self-view application that renders the local video in an OpenGL view. The application uses the OpenWebRTC C API. The gist of the app:
```
g_object_get(source, "type", &source_type, "media-type", &media_type, NULL);

if (media_type == OWR_MEDIA_TYPE_VIDEO && source_type == OWR_SOURCE_TYPE_CAPTURE) {
    renderer = owr_video_renderer_new(SELF_VIEW_TAG);
    g_assert(renderer);

    g_object_set(renderer, "width", 1280, "height", 720, "max-framerate", 30.0, NULL);

    owr_media_renderer_set_source(OWR_MEDIA_RENDERER(renderer), source);
}
```
