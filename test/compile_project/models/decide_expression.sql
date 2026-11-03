select {{ drex.drex_decide('payload', {'refund': {'type': 'noul', 'instructions': 'Refund?'}}, model='drex-max') }} as answer from tickets
