from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from flask import Response, request


# Compteur de requêtes HTTP : méthodes, endpoints et codes de statut
request_counter = Counter(
    "http_requests_total",
    "Nombre total de requêtes HTTP",
    ["method", "endpoint", "status"],
)

# Histogramme de latence des requêtes (buckets en secondes)
request_latency = Histogram(
    "http_request_duration_seconds",
    "Durée de traitement des requêtes HTTP",
    ["method", "endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)


def init_metrics(app):
    """Attache les hooks de métriques à l'application Flask."""

    @app.before_request
    def _before_request():
        # On ignore l'endpoint /metrics pour éviter l'auto-comptage
        if request.path == "/metrics":
            return
        request._start_time = app.clock()

    @app.after_request
    def _after_request(response):
        if request.path == "/metrics":
            return response

        status = str(response.status_code)
        url_rule = getattr(request, "url_rule", None)
        endpoint = url_rule.rule if url_rule else request.path
        request_counter.labels(method=request.method, endpoint=endpoint, status=status).inc()

        elapsed = app.clock() - getattr(request, "_start_time", 0)
        request_latency.labels(method=request.method, endpoint=endpoint).observe(elapsed)

        return response

    @app.route("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
