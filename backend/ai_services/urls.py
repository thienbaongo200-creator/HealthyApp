from django.urls import path
from .views import (
    AiChatSessionView,
    AiConversationListView,
    AiConversationMessagesView,
)

urlpatterns = [
    path('conversations/', AiConversationListView.as_view(), name='ai-conversation-list'),
    path(
        'conversations/<uuid:conversation_id>/messages/',
        AiConversationMessagesView.as_view(),
        name='ai-conversation-messages',
    ),
    path('chat/<uuid:profile_id>/', AiChatSessionView.as_view(), name='ai-chat-session'),
]
