package com.example.availableinv;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * availableInv —— 简单的可用库存服务(fake 数据)。
 * client 查询某 SKU 的可用库存,始终返回一个固定值。
 */
@RestController
public class InventoryController {

    // 固定返回值(fake)
    private static final int FIXED_AVAILABLE_QTY = 42;

    @GetMapping("/")
    public Map<String, Object> root() {
        return Map.of(
            "service", "availableInv",
            "message", "GET /inventory/available?sku=<id>"
        );
    }

    @GetMapping("/inventory/available")
    public Map<String, Object> available(
            @RequestParam(name = "sku", defaultValue = "UNKNOWN") String sku) {
        return Map.of(
            "sku", sku,
            "availableQuantity", FIXED_AVAILABLE_QTY,
            "source", "fake",
            "timestamp", Instant.now().toString()
        );
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }
}
