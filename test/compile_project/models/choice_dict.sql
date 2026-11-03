select {{ drex.drex_choice('body', 'Which team?', {'billing': none, 'technical': none}) }} as answer from tickets
