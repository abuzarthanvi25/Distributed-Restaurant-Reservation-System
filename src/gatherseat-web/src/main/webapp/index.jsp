<%@ page contentType="text/html;charset=UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<h1>GatherSeat</h1>
<p><c:out value="${pageContext.request.contextPath}"/> works</p>
<form method="post" action="${pageContext.request.contextPath}/login">
    <button type="submit" class="link">Login</button>
</form>