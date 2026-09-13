# Battle particles

`smoke-puff-v1.png` was generated using OpenAI ImageGen for this project.
It is a neutral smoke sprite with transparency, tinted and rotated by the
particle shader for smoke, fire and dust. No third-party game assets were copied.

The particle buffer is capped at 1,200 entries. A procedural fallback is used
until the image loads, or if it is missing. The image is served locally; running
the game does not call an image-generation service.
