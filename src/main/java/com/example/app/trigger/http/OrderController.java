package com.example.app.trigger.http;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import com.example.app.trigger.http.dto.PlaceOrderRequest;
import com.example.app.types.Response;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;

/**
 * 触发器/适配器层：只做协议转换（DTO -> Command），把活儿交给 application 用例。
 * 不直接调多个领域服务，避免业务编排散落到 Controller。
 */
@RestController
@RequestMapping("/api/order")
public class OrderController {

    @Resource
    private IOrderPlaceUseCase orderPlaceUseCase;

    @PostMapping("/place")
    public Response<OrderResult> place(@RequestBody PlaceOrderRequest request) {
        List<PlaceOrderCommand.Item> items = new ArrayList<>();
        if (request.getItems() != null) {
            for (PlaceOrderRequest.Item i : request.getItems()) {
                items.add(PlaceOrderCommand.Item.builder()
                        .productName(i.getProductName())
                        .quantity(i.getQuantity())
                        .price(i.getPrice())
                        .build());
            }
        }
        PlaceOrderCommand command = PlaceOrderCommand.builder()
                .userId(request.getUserId())
                .items(items)
                .build();
        return Response.ok(orderPlaceUseCase.placeOrder(command));
    }

    // 故意的编译错误：引用不存在的类型
    @PostMapping("/broken")
    public Response<BrokenType> broken() {
        return null;
    }
}
