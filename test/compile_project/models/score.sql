select {{ drex.drex_score('body', 'How urgent is this ticket?', ['can wait', 'this week', 'today'], model='drex-max') }} as answer from tickets
