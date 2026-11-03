{{ config(enabled=target.type != "duckdb") }}
select {{ drex.drex_decide_image({"note": "note"}, "images", {"kind": {"type": "choice", "criteria": ["invoice", "receipt"]}}, model="drex-max-v1.1") }} as answer from photos
