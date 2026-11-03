select {{ drex.drex_choice_value('team') }} as team, {{ drex.drex_score_value('urgency') }} as urgency, {{ drex.drex_confidence('team') }} as confidence from answers
