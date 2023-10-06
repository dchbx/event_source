# frozen_string_literal: true

module Fixtures
  module EventTransactions
    [
      {
        hbx_id: '213',
        legal_name: 'dchbx',
        entity_kind: 's_corp',
        fein: '87879867',
        metadata: {
          command_name: :create,
          record_state: {
            x_id: '213',
            legal_name: 'dchbx',
            entity_kind: 's_corp',
            fein: '87879867'
          }
        }
      },
      {
        hbx_id: '213',
        legal_name: 'dchbx',
        entity_kind: 'c_corp',
        metadata: {
          command_name: :update_entity_kind,
          record_state: {
            x_id: '213',
            legal_name: 'dchbx',
            entity_kind: 'c_corp',
            fein: '87879867'
          }
        }
      },
      {
        hbx_id: '213',
        fein: '99999999',
        metadata: {
          command_name: :update_fein,
          # submitted_at: DateTime.now.to_s,
          # correlation_id: 8_383_838,
          correlation_id: '8383838',
          record_state: {
            x_id: '213',
            legal_name: 'dchbx',
            entity_kind: 'c_corp',
            fein: '99999999'
          }
        }
      }
    ]
  end
end
