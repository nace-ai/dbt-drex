select {{ drex.drex_fingerprint('body', {'instructions': 'Which team?', 'labels': ['billing', 'technical']}) }} as fingerprint from tickets
