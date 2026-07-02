package com.example.app.trigger.http;

import com.example.app.types.AppException;
import com.example.app.types.Constants;
import com.example.app.types.Response;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 全局异常处理（HTTP 入站适配的一部分，故放在 trigger/http 层）。
 * <p>把各类异常统一翻译成 {@link Response} 信封，让 {@link Constants.ResponseCode} 真正用起来，
 * 避免异常堆栈直接抛给调用方。
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** 业务异常：HTTP 200，错误信息在信封里（业务失败是正常返回） */
    @ExceptionHandler(AppException.class)
    public Response<Void> handleAppException(AppException e) {
        log.warn("业务异常 code={} info={}", e.getCode(), e.getMessage());
        return Response.<Void>builder().code(e.getCode()).info(e.getMessage()).build();
    }

    /** 参数/请求体异常：HTTP 400 */
    @ExceptionHandler({IllegalArgumentException.class, HttpMessageNotReadableException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Response<Void> handleIllegalArgument(Exception e) {
        log.warn("参数异常：{}", e.getMessage());
        return Response.error(Constants.ResponseCode.ILLEGAL_PARAMETER);
    }

    /** 兜底未知异常：HTTP 500，记录堆栈，对外只暴露统一错误码 */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Response<Void> handleUnknown(Exception e) {
        log.error("系统异常", e);
        return Response.error(Constants.ResponseCode.UN_ERROR);
    }
}
