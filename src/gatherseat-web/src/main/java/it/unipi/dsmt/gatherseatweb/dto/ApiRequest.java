package it.unipi.dsmt.gatherseatweb.dto;

public class ApiRequest<T> {

    private String requestId;
    private T data;

    public ApiRequest() {
    }

    public ApiRequest(String requestId, T data) {
        this.requestId = requestId;
        this.data = data;
    }

    public String getRequestId() {
        return requestId;
    }

    public T getData() {
        return data;
    }

    public void setRequestId(String requestId) {
        this.requestId = requestId;
    }

    public void setData(T data) {
        this.data = data;
    }
}
