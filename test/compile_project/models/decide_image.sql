{{ config(enabled=target.type != "duckdb") }}
select {{ drex.drex_decide_image("state", "images", {"receipt": {"type": "noul", "instructions": "Is Image 1 a receipt?"}}) }} as answer from photos
