const pendingBatches = new Map()
const activeBatches = new Map()

class SolidObjectsBatchRefreshElement extends HTMLElement {
  connectedCallback() {
    if (this.dataset.started === "true") return
    this.dataset.started = "true"
    this.enqueue()
  }

  enqueue() {
    const batch = this.dataset.batch
    const revision = this.dataset.revision
    const source = this.dataset.source
    const scope = this.closest("[id]")?.id
    if (!batch || !revision || !source || !scope) return this.remove()

    const group = `${scope}:${batch}`
    const key = `${group}:${revision}`
    const pending = pendingBatches.get(key)
    if (pending) {
      pending.sources.add(source)
      return this.remove()
    }

    const merged = { sources: new Set([source]) }
    pendingBatches.set(key, merged)
    queueMicrotask(() => {
      pendingBatches.delete(key)
      requestBatch(group, batch, merged.sources)
    })
    this.remove()
  }
}

async function requestBatch(group, batch, sources) {
  activeBatches.get(group)?.abort()
  const controller = new AbortController()
  activeBatches.set(group, controller)

  try {
    const url = mergedUrl(sources)
    if (!url) return
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
      redirect: "error",
      signal: controller.signal
    })
    if (!response.ok) return dispatchBatchError(batch, `http_${response.status}`)
    const body = await response.json()
    if (!Array.isArray(body?.frames)) return dispatchBatchError(batch, "invalid_response")
    body.frames.forEach(applyFrame)
  } catch (error) {
    if (error.name !== "AbortError") dispatchBatchError(batch, "request_failed")
  } finally {
    if (activeBatches.get(group) === controller) activeBatches.delete(group)
  }
}

function mergedUrl(sources) {
  const urls = [...sources].map((source) => new URL(source, window.location.href))
  const first = urls[0]
  if (!first || urls.some((url) => url.origin !== first.origin)) return
  const tokens = new Set(urls.flatMap((url) => url.searchParams.getAll("tokens[]")))
  first.searchParams.delete("tokens[]")
  tokens.forEach((token) => first.searchParams.append("tokens[]", token))
  return first
}

function applyFrame(frame) {
  const target = document.getElementById(frame?.target)
  if (!target || !frame.html || !newerRevision(frame.revision, target.dataset.solidObjectsRevision)) return
  const replacement = new DOMParser().parseFromString(frame.html, "text/html").getElementById(frame.target)
  if (!replacement) return

  const stream = document.createElement("turbo-stream")
  stream.setAttribute("action", "replace")
  if (frame.refresh_method === "morph") stream.setAttribute("method", "morph")
  stream.setAttribute("target", frame.target)
  const template = document.createElement("template")
  template.content.append(document.importNode(replacement, true))
  stream.append(template)
  document.documentElement.append(stream)
}

function newerRevision(candidate, current) {
  const candidateRevision = parseRevision(candidate)
  const currentRevision = parseRevision(current)
  if (!candidateRevision || !currentRevision) return false
  return candidateRevision[0] > currentRevision[0] ||
    (candidateRevision[0] === currentRevision[0] && candidateRevision[1] > currentRevision[1])
}

function parseRevision(revision) {
  if (!revision) return
  const values = String(revision).split(":").map(Number)
  if (values.length !== 2 || values.some((value) => !Number.isSafeInteger(value) || value < 0)) return
  return values
}

function dispatchBatchError(batch, reason) {
  document.dispatchEvent(new CustomEvent("solid-objects:batch-refresh-error", {
    bubbles: true,
    detail: { batch, reason }
  }))
}

if (!customElements.get("solid-objects-batch-refresh")) {
  customElements.define("solid-objects-batch-refresh", SolidObjectsBatchRefreshElement)
}
