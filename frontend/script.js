const services = [
    { id: "users", url: "/api/users/health" },
    { id: "products", url: "/api/products/health" },
    { id: "orders", url: "/api/orders/health" }
];

async function checkServices() {
    for (const service of services) {
        const element = document.getElementById(service.id);

        try {
            const response = await fetch(service.url);
            if (!response.ok) throw new Error("Service unavailable");

            const data = await response.json();
            element.textContent =
                data.status === "ok" || data.status === "healthy"
                    ? "● Running"
                    : "● Unhealthy";
        } catch {
            element.textContent = "● Unavailable";
        }
    }
}

checkServices();
setInterval(checkServices, 30000);
