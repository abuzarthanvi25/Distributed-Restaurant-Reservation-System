
package it.unipi.dsmt.gatherseatweb.dto;

import java.time.Instant;

public class ApiResponse<T> {

    private boolean success;
    private String message;
    private String requestId;
    private T data;
    private String timestamp;

    public ApiResponse() {
        this.timestamp = Instant.now().toString();
    }

    public ApiResponse(
            boolean success,
            String message,
            String requestId,
            T data
    ) {
        this.success = success;
        this.message = message;
        this.requestId = requestId;
        this.data = data;
        this.timestamp = Instant.now().toString();
    }

    public static <T> ApiResponse<T> success(
            String message,
            String requestId,
            T data
    ) {
        return new ApiResponse<>(true, message, requestId, data);
    }

    public static <T> ApiResponse<T> error(
            String message,
            String requestId
    ) {
        return new ApiResponse<>(false, message, requestId, null);
    }

    public boolean isSuccess() {
        return success;
    }

    public String getMessage() {
        return message;
    }

    public String getRequestId() {
        return requestId;
    }

    public T getData() {
        return data;
    }

    public String getTimestamp() {
        return timestamp;
    }
}
