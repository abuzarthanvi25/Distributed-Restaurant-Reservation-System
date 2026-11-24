
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<!DOCTYPE html>
<html lang="en">
<head>
    <title>My bookings – GatherSeat</title>
    <%@ include file="/WEB-INF/jspf/head.jspf" %>
</head>

<body data-ctx="${pageContext.request.contextPath}"
      data-user-id="<c:out value='${sessionScope.user.id}'/>">

<%@ include file="/WEB-INF/jspf/nav.jspf" %>

<main class="container">
    <div class="page-header">
        <h1>My Bookings</h1>
    </div>
</main>

<script src="./assets/js/pages/my-bookings.js"></script>
</body>
</html>
