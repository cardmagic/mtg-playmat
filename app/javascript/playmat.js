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

  async function sendAction(action) {
    const playmat = playmatElement()
    if (!playmat) {
      return
    }

    const response = await fetch(playmat.dataset.actionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
      body: JSON.stringify({ action: action }),
    })
    if (response.ok) {
      return
    }

    const payload = await response.json().catch(function () {
      return null
    })
    alert(payload?.error || 'Action failed')
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

  document.addEventListener('click', async function (event) {
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
