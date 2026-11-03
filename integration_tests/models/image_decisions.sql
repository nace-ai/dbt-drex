{#-
  Questions about two images, in both orders, with Drex Max (drex_decide_image's default). Postgres only here: each
  warehouse takes images in its own form (staged files, signed URLs, bytes), and drex-duckdb has no drex_decide_image.
-#}
{{ config(enabled=target.type == "postgres") }}

{% set questions = {"first": {"type": "choice", "instructions": "What colour is Image 1?", "criteria": ["red", "blue"]}} %}

with images as (
    select
        decode(max(case when name = 'red' then png_base64 end), 'base64') as red,
        decode(max(case when name = 'blue' then png_base64 end), 'base64') as blue
    from {{ ref("images") }}
)

select 'red' as images_order, {{ drex.drex_decide_image("'\"Two test images\"'::jsonb", "array[red]", questions) }} as decision
from images
union all
select 'red_then_blue', {{ drex.drex_decide_image("'\"Two test images\"'::jsonb", "array[red, blue]", questions) }}
from images
union all
select 'blue_then_red', {{ drex.drex_decide_image("'\"Two test images\"'::jsonb", "array[blue, red]", questions) }}
from images
