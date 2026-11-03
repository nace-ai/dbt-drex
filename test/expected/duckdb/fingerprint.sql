select md5(cast('{"model": null, "question": {"instructions": "Which team?", "labels": ["billing", "technical"]}}' || coalesce('v' || cast(body as TEXT), 'n') as TEXT)) as fingerprint from tickets
