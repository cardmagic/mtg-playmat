(function () {
  let battlefieldCardDrag = null
  let counterDrag = null
  let counterPaletteDrag = null

  function playmatElement() {
    return document.querySelector('[data-playmat]')
  }

  function currentPlayerId() {
    return playmatElement()?.dataset.currentPlayerId
  }

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  function currentPlayerSection() {
    return document.querySelector('.player-section[data-current-player="true"]')
  }

  function isCurrentPlayer(player, currentId) {
    return String(player.id) === String(currentId)
  }

  function adjustZoneCount(zone, amount) {
    const countElement = currentPlayerSection()?.querySelector(`[data-zone-count="${zone}"]`)
    if (!countElement) {
      return
    }

    const nextCount = Math.max(0, Number(countElement.dataset.count) + amount)
    countElement.dataset.count = nextCount
    countElement.textContent = `${countElement.dataset.zoneLabel} ${nextCount}`
  }

  function applyInstantFeedback(form, submitter) {
    submitter?.classList.add('is-submitting')

    switch (form.dataset.instantAction) {
      case 'draw_card':
        adjustZoneCount('library', -1)
        adjustZoneCount('hand', 1)
        break
      case 'play_from_hand':
        adjustZoneCount('hand', -1)
        break
    }
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>\"']/g, function (character) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]
    })
  }

  function clientAction(action, label, className = '') {
    return `<button type="button" class="${className}" data-client-action='${escapeHtml(JSON.stringify(action))}'>${label}</button>`
  }

  function cardPreview(card) {
    return `data-preview-image="${escapeHtml(card.imageUrl)}" data-preview-name="${escapeHtml(card.name)}"`
  }

  function renderPlayer(player, current) {
    const zones = ['graveyard', 'exile']
    const hand = current ? player.hand.slice().reverse().map(function (card) {
      return `<button type="button" class="hand-card" ${cardPreview(card)} data-client-action='${escapeHtml(JSON.stringify({ type: 'play_from_hand', instanceId: card.instanceId }))}'>` +
        `<img loading="lazy" src="${escapeHtml(card.imageUrl)}" alt="${escapeHtml(card.name)}"><span>${escapeHtml(card.name)}</span></button>`
    }).join('') : ''
    const battlefield = player.battlefield.map(function (card) {
      const tools = current ? [
        clientAction({ type: 'move_card_zone', instanceId: card.instanceId, from: 'battlefield', to: 'hand' }, '🖐️', 'card-tool'),
        clientAction({ type: 'move_to_deck', instanceId: card.instanceId, from: 'battlefield', position: 'top' }, '⬆️', 'card-tool'),
        clientAction({ type: 'move_to_deck', instanceId: card.instanceId, from: 'battlefield', position: 'bottom' }, '⬇️', 'card-tool'),
        clientAction({ type: 'move_to_deck', instanceId: card.instanceId, from: 'battlefield', position: 'shuffle' }, '🔀', 'card-tool'),
        clientAction({ type: 'move_card_zone', instanceId: card.instanceId, from: 'battlefield', to: 'graveyard' }, '🪦', 'card-tool'),
        clientAction({ type: 'move_card_zone', instanceId: card.instanceId, from: 'battlefield', to: 'exile' }, '✨', 'card-tool')
      ].join('') : ''
      const counters = card.counters.map(function (counter) {
        const controls = current ? clientAction({ type: 'update_counter_value', instanceId: card.instanceId, counterId: counter.id, delta: -1 }, '-') +
          clientAction({ type: 'update_counter_value', instanceId: card.instanceId, counterId: counter.id, delta: 1 }, '+') : ''
        return `<div class="counter-chip${current ? '' : ' read-only-counter'}" data-counter-id="${escapeHtml(counter.id)}" data-instance-id="${escapeHtml(card.instanceId)}" style="left:${counter.x}px;top:${counter.y}px">${controls}<span class="counter-value">${counter.value}</span></div>`
      }).join('')
      return `<div class="battlefield-card${card.tapped ? ' tapped' : ''}" data-instance-id="${escapeHtml(card.instanceId)}" data-player-id="${escapeHtml(player.id)}" ${cardPreview(card)} style="left:${card.x}px;top:${card.y}px">` +
        `<img loading="lazy" src="${escapeHtml(card.imageUrl)}" alt="${escapeHtml(card.name)}"><div class="card-tools">${tools}</div>${counters}</div>`
    }).join('')
    const lanes = zones.map(function (zone) {
      const cards = player[zone].slice().reverse().map(function (card, index) {
        const action = { type: 'move_card_zone', instanceId: card.instanceId, from: zone, to: 'battlefield', x: 48, y: 48 }
        const content = `<img loading="lazy" src="${escapeHtml(card.imageUrl)}" alt="${escapeHtml(card.name)}">${zone === 'graveyard' && index === 0 ? '<em class="zone-top-badge">TOP</em>' : ''}<span>${escapeHtml(card.name)}</span>`
        return current ? clientAction(action, content, `zone-card-chip${zone === 'graveyard' && index === 0 ? ' top-zone-card' : ''}`) : `<div class="zone-card-chip read-only">${content}</div>`
      }).join('')
      return `<div class="zone-lane"><span class="zone-lane-label">${zone[0].toUpperCase() + zone.slice(1)}${current ? ' (click to move to battlefield)' : ''}</span><div class="zone-lane-cards">${cards}</div></div>`
    }).join('')

    return `<section class="player-section ${current ? 'your-seat' : 'opponent-seat'}" data-player-id="${escapeHtml(player.id)}" data-current-player="${current}">` +
      `<header class="player-header"><div class="player-header-name"><strong>${escapeHtml(player.name)}</strong>${!current && player.isSearchingDeck ? '<span class="searching-indicator">Looking through library...</span>' : ''}</div>` +
      `<div class="life-controls">${current ? clientAction({ type: 'adjust_life', delta: -1 }, '-') : ''}<span class="life-value">${player.life}</span>${current ? clientAction({ type: 'adjust_life', delta: 1 }, '+') + clientAction({ type: 'reset_life' }, 'Reset') : ''}</div></header>` +
      `<div class="zone-summary"><span>Selected: ${escapeHtml(player.deckName || 'not loaded')}</span>${['library', 'hand', 'graveyard', 'exile'].map(function (zone) { return `<span data-zone-count="${zone}" data-zone-label="${zone[0].toUpperCase() + zone.slice(1)}" data-count="${player[zone].length}">${zone[0].toUpperCase() + zone.slice(1)} ${player[zone].length}</span>` }).join('')}</div>` +
      (current ? `<div class="hand-strip">${hand}</div>` : '') +
      `<div class="battlefield"><div class="battlefield-canvas" data-battlefield-player-id="${escapeHtml(player.id)}">${battlefield}</div></div><div class="zone-lanes">${lanes}</div></section>`
  }

  function renderPayloadBoard(payload) {
    const playmat = playmatElement()
    const players = payload?.space?.players || []
    if (!playmat || players.length === 0) {
      return
    }

    const version = Number(payload.space.version || 0)
    if (version <= Number(playmat.dataset.roomVersion || 0)) {
      return
    }

    playmat.dataset.roomVersion = String(version)
    const currentId = payload.currentPlayerId
    const orderedPlayers = players.slice().sort(function (left, right) {
      return isCurrentPlayer(left, currentId) ? -1 : isCurrentPlayer(right, currentId) ? 1 : 0
    })
    const playersArea = document.getElementById('players-area')
    if (playersArea) {
      const playerFrames = Array.from(playersArea.querySelectorAll('turbo-frame'))
      orderedPlayers.forEach(function (player, index) {
        const frame = playerFrames[index]
        if (!frame) {
          return
        }

        frame.innerHTML = renderPlayer(player, isCurrentPlayer(player, currentId))
        playersArea.appendChild(frame)
      })
    }

    playmat.classList.remove('is-action-pending')
    playmat.removeAttribute('aria-busy')
  }

  document.addEventListener('solid-objects:payload', function (event) {
    if (event.detail.name !== 'playmat_state') {
      return
    }

    renderPayloadBoard(event.detail.payload)
  })

  async function sendAction(action) {
    const playmat = playmatElement()
    if (!playmat) {
      return
    }

    playmat.classList.add('is-action-pending')
    playmat.setAttribute('aria-busy', 'true')
    try {
      const response = await fetch(playmat.dataset.actionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken(),
        },
        body: JSON.stringify({ action: action }),
      })
      const payload = await response.json().catch(function () {
        return null
      })
      if (response.ok && payload?.space) {
        renderPayloadBoard(payload)
        return payload
      }

      alert(payload?.error || 'Action failed')
    } finally {
      playmat.classList.remove('is-action-pending')
      playmat.removeAttribute('aria-busy')
    }
  }

  async function submitImmediateDeck(form) {
    const playmat = playmatElement()
    const submitter = form.querySelector('[type="submit"]')
    if (!playmat || !submitter) {
      return
    }

    submitter.disabled = true
    form.classList.add('is-action-pending')
    try {
      const response = await fetch(form.action, {
        method: 'POST',
        body: new FormData(form),
        credentials: 'same-origin',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken(),
        },
      })
      const payload = await response.json().catch(function () {
        return null
      })
      if (response.ok && payload?.space) {
        renderPayloadBoard(payload)
        return
      }

      alert(payload?.error || 'Could not load deck')
    } finally {
      submitter.disabled = false
      form.classList.remove('is-action-pending')
    }
  }

  function belongsToCurrentPlayer(element) {
    return element?.dataset.playerId === currentPlayerId()
  }

  function beginBattlefieldCardDrag(event, cardElement) {
    if (event.target.closest('button, form, a, input, details, summary, .counter-chip')) {
      return
    }
    if (!belongsToCurrentPlayer(cardElement)) {
      return
    }

    const battlefield = cardElement.closest('.battlefield-canvas')
    if (!battlefield) {
      return
    }

    const cardRectangle = cardElement.getBoundingClientRect()
    const battlefieldRectangle = battlefield.getBoundingClientRect()
    battlefieldCardDrag = {
      cardElement: cardElement,
      instanceId: cardElement.dataset.instanceId,
      offsetX: event.clientX - cardRectangle.left,
      offsetY: event.clientY - cardRectangle.top,
      battlefieldLeft: battlefieldRectangle.left,
      battlefieldTop: battlefieldRectangle.top,
      startClientX: event.clientX,
      startClientY: event.clientY,
      hasMoved: false,
    }
    cardElement.classList.add('is-dragging')
    cardElement.setPointerCapture(event.pointerId)
    event.preventDefault()
  }

  function moveBattlefieldCard(event) {
    if (!battlefieldCardDrag) {
      return
    }

    const movement =
      Math.abs(event.clientX - battlefieldCardDrag.startClientX) +
      Math.abs(event.clientY - battlefieldCardDrag.startClientY)
    if (!battlefieldCardDrag.hasMoved && movement < 3) {
      return
    }

    battlefieldCardDrag.hasMoved = true
    const position = battlefieldCardPosition(event)
    battlefieldCardDrag.cardElement.style.left = position.x + 'px'
    battlefieldCardDrag.cardElement.style.top = position.y + 'px'
  }

  function battlefieldCardPosition(event) {
    return {
      x: Math.max(
        0,
        event.clientX - battlefieldCardDrag.battlefieldLeft - battlefieldCardDrag.offsetX
      ),
      y: Math.max(
        0,
        event.clientY - battlefieldCardDrag.battlefieldTop - battlefieldCardDrag.offsetY
      ),
    }
  }

  function finishBattlefieldCardDrag(event) {
    if (!battlefieldCardDrag) {
      return
    }

    const position = battlefieldCardPosition(event)
    const instanceId = battlefieldCardDrag.instanceId
    const hasMoved = battlefieldCardDrag.hasMoved
    battlefieldCardDrag.cardElement.classList.remove('is-dragging')
    battlefieldCardDrag = null

    if (!hasMoved) {
      sendAction({ type: 'toggle_tap', instanceId: instanceId })
      return
    }

    sendAction({
      type: 'move_battlefield_card',
      instanceId: instanceId,
      x: position.x,
      y: position.y,
    })
  }

  function beginCounterDrag(event, counterElement) {
    if (event.target.closest('button, form')) {
      return
    }

    const cardElement = counterElement.closest('.battlefield-card')
    if (!belongsToCurrentPlayer(cardElement)) {
      return
    }

    const cardRectangle = cardElement.getBoundingClientRect()
    const counterRectangle = counterElement.getBoundingClientRect()
    counterDrag = {
      counterElement: counterElement,
      instanceId: counterElement.dataset.instanceId,
      counterId: counterElement.dataset.counterId,
      cardRectangle: cardRectangle,
      offsetX: event.clientX - counterRectangle.left,
      offsetY: event.clientY - counterRectangle.top,
    }
    counterElement.setPointerCapture(event.pointerId)
  }

  function moveCounter(event) {
    if (!counterDrag) {
      return
    }

    const position = counterPosition(event)
    counterDrag.counterElement.style.left = position.x + 'px'
    counterDrag.counterElement.style.top = position.y + 'px'
  }

  function counterPosition(event) {
    return {
      x: Math.max(
        0,
        event.clientX - counterDrag.cardRectangle.left - counterDrag.offsetX
      ),
      y: Math.max(
        0,
        event.clientY - counterDrag.cardRectangle.top - counterDrag.offsetY
      ),
    }
  }

  function finishCounterDrag(event) {
    if (!counterDrag) {
      return
    }

    const position = counterPosition(event)
    const action = {
      type: 'move_counter',
      instanceId: counterDrag.instanceId,
      counterId: counterDrag.counterId,
      x: position.x,
      y: position.y,
    }
    counterDrag = null
    sendAction(action)
  }

  function beginCounterPaletteDrag(event) {
    const ghost = document.createElement('div')
    ghost.className = 'counter-palette-token'
    ghost.textContent = '+1/+1'
    ghost.style.position = 'fixed'
    ghost.style.pointerEvents = 'none'
    ghost.style.opacity = '0.86'
    document.body.appendChild(ghost)
    counterPaletteDrag = { ghost: ghost }
    moveCounterPalette(event)
    event.preventDefault()
  }

  function moveCounterPalette(event) {
    if (!counterPaletteDrag) {
      return
    }

    counterPaletteDrag.ghost.style.left = event.clientX + 'px'
    counterPaletteDrag.ghost.style.top = event.clientY + 'px'
    document.querySelectorAll('.battlefield-card.drop-target').forEach(function (card) {
      card.classList.remove('drop-target')
    })
    const cardElement = document.elementFromPoint(event.clientX, event.clientY)?.closest('.battlefield-card')
    if (belongsToCurrentPlayer(cardElement)) {
      cardElement.classList.add('drop-target')
    }
  }

  function finishCounterPaletteDrag(event) {
    if (!counterPaletteDrag) {
      return
    }

    counterPaletteDrag.ghost.remove()
    counterPaletteDrag = null
    const cardElement = document.elementFromPoint(event.clientX, event.clientY)?.closest('.battlefield-card')
    document.querySelectorAll('.battlefield-card.drop-target').forEach(function (card) {
      card.classList.remove('drop-target')
    })
    if (!belongsToCurrentPlayer(cardElement)) {
      return
    }

    const cardRectangle = cardElement.getBoundingClientRect()
    sendAction({
      type: 'add_counter',
      instanceId: cardElement.dataset.instanceId,
      x: Math.max(0, event.clientX - cardRectangle.left - 18),
      y: Math.max(0, event.clientY - cardRectangle.top - 12),
      label: '+1/+1',
    })
  }

  function resetDrags() {
    battlefieldCardDrag?.cardElement.classList.remove('is-dragging')
    counterPaletteDrag?.ghost.remove()
    battlefieldCardDrag = null
    counterDrag = null
    counterPaletteDrag = null
  }

  function showCardPreview(element) {
    const imageUrl = element?.dataset.previewImage
    if (!imageUrl) {
      return
    }

    const preview = document.getElementById('card-hover-preview')
    const image = document.getElementById('card-hover-preview-image')
    const name = document.getElementById('card-hover-preview-name')
    image.src = imageUrl
    image.alt = element.dataset.previewName || 'Card preview'
    name.textContent = element.dataset.previewName || ''
    preview.classList.add('is-visible')
  }

  function hideCardPreview() {
    document.getElementById('card-hover-preview')?.classList.remove('is-visible')
  }

  async function copyText(text) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text)
      return
    }

    const input = document.createElement('textarea')
    input.value = text
    input.style.position = 'fixed'
    input.style.opacity = '0'
    document.body.appendChild(input)
    input.select()
    const copied = document.execCommand('copy')
    input.remove()
    if (!copied) {
      throw new Error('Copy failed')
    }
  }

  document.addEventListener('pointerdown', function (event) {
    const palette = event.target.closest('[data-counter-palette]')
    if (palette) {
      beginCounterPaletteDrag(event)
      return
    }

    const counter = event.target.closest('.counter-chip')
    if (counter) {
      beginCounterDrag(event, counter)
      return
    }

    const card = event.target.closest('.battlefield-card')
    if (card) {
      beginBattlefieldCardDrag(event, card)
    }
  })

  document.addEventListener('pointermove', function (event) {
    moveBattlefieldCard(event)
    moveCounter(event)
    moveCounterPalette(event)
  })

  document.addEventListener('pointerup', function (event) {
    finishBattlefieldCardDrag(event)
    finishCounterDrag(event)
    finishCounterPaletteDrag(event)
  })

  document.addEventListener('pointercancel', resetDrags)
  document.addEventListener('turbo:before-frame-render', resetDrags)

  document.addEventListener('turbo:submit-start', function (event) {
    const form = event.target
    if (!form.matches('.inline-action, .contents-action')) {
      return
    }

    form.classList.add('is-action-pending')
    form.setAttribute('aria-busy', 'true')
    const submitter = event.detail.formSubmission.submitter
    applyInstantFeedback(form, submitter)
    submitter?.setAttribute('disabled', 'disabled')
  })

  document.addEventListener('turbo:submit-end', function (event) {
    const form = event.target
    if (!form.matches('.inline-action, .contents-action')) {
      return
    }

    form.classList.remove('is-action-pending')
    form.removeAttribute('aria-busy')
    event.detail.formSubmission.submitter?.removeAttribute('disabled')
  })

  document.addEventListener('submit', function (event) {
    const form = event.target.closest('form[data-immediate-action="load_deck"]')
    if (!form) {
      return
    }

    event.preventDefault()
    submitImmediateDeck(form)
  })

  document.addEventListener('click', async function (event) {
    const actionButton = event.target.closest('[data-client-action]')
    if (actionButton) {
      event.preventDefault()
      actionButton.disabled = true
      try {
        await sendAction(JSON.parse(actionButton.dataset.clientAction))
      } finally {
        actionButton.disabled = false
      }
      return
    }

    const copyButton = event.target.closest('[data-copy-text]')
    if (!copyButton) {
      return
    }

    try {
      await copyText(copyButton.dataset.copyText)
      copyButton.textContent = 'Copied!'
      window.setTimeout(function () {
        copyButton.textContent = 'Copy Share Link to Clipboard'
      }, 1400)
    } catch {
      alert('Copy failed')
    }
  })

  document.addEventListener('input', function (event) {
    if (!event.target.matches('[data-library-filter]')) {
      return
    }

    const query = event.target.value.trim().toLowerCase()
    document.querySelectorAll('[data-library-card-name]').forEach(function (form) {
      form.hidden = !form.dataset.libraryCardName.includes(query)
    })
  })

  document.addEventListener('mouseover', function (event) {
    showCardPreview(event.target.closest('[data-preview-image]'))
  })
  document.addEventListener('mouseout', hideCardPreview)
  document.addEventListener('focusin', function (event) {
    showCardPreview(event.target.closest('[data-preview-image]'))
  })
  document.addEventListener('focusout', hideCardPreview)
})()
