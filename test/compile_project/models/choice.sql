select {{ drex.drex_choice('body', 'Which team should handle this ticket?', ['billing', 'technical', 'sales']) }} as answer from tickets
