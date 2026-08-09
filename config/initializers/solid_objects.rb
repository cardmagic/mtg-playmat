SolidObjects.configure do |configuration|
  configuration.worker_count = 1
  configuration.effect_worker_count = 1
  configuration.broadcast_worker_count = 1
  configuration.reminder_scheduler_count = 1
  configuration.polling_interval = 0.02.seconds
  configuration.message_retention = 30.days
  configuration.message_retention_by_actor_type = {
    "playmat_room" => 1.day
  }
  configuration.process_retention = 7.days
  configuration.prune_batch_size = 1_000
  configuration.component_authorization_context = lambda do |controller:|
    registration = SolidObjects::ComponentRegistration.from_token(
      controller.params.require(:token)
    )
    authorization = Playmat::Authorization.new(
      room_code: registration.reference.actor_id,
      session_id: controller.request.cookie_jar.signed[Playmat::SESSION_COOKIE]
    )
    room = registration.reference.snapshot(authorization_context: authorization).room
    authorization if authorization.player_in?(room)
  end

  authorize_room = lambda do |actor_type:, actor_id:, authorization_context:, **|
    authorization_context.is_a?(Playmat::Authorization) &&
      authorization_context.valid_for?(actor_type:, actor_id:)
  end

  configuration.authorize_message = authorize_room
  configuration.authorize_query = authorize_room
  configuration.authorize_destroy = ->(**) { false }
  configuration.authorize_subscription = lambda do |actor_type:, actor_id:, authorization_context:, **|
    session_id = authorization_context.playmat_session_id if
      authorization_context.respond_to?(:playmat_session_id)
    next false unless actor_type == PlaymatRoom.actor_type && session_id.present?

    authorization = Playmat::Authorization.new(room_code: actor_id, session_id:)
    room = PlaymatRoom.ref(actor_id).snapshot(authorization_context: authorization).room
    authorization.player_in?(room)
  end
  configuration.authorize_administration = ->(**) { false }
end
