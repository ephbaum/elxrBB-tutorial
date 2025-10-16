# Lesson 5: Implementing Sub-Topics and Displaying Sub-Topic Counts

In this lesson, we will be adding sub-topic functionality to threaded replies and updating the UI to display sub-topic counts. We will also provide a view for users to see sub-topics.

1. **Adding sub-topic functionality to threaded replies**

Since we have already implemented threaded replies in the previous lesson, we can reuse the existing structure to create sub-topics. Sub-topics will be replies that are associated with a parent reply instead of a main topic. To create a sub-topic, users will click on a "Reply" button within a reply, which will open a new reply form with the `parent_id` set to the ID of the parent reply.

2. **Updating the UI to display sub-topic counts**

To show the number of sub-topics for each reply, we'll update the `lib/elxr_bb_web/templates/topic/show.html.eex` file. Add a new line within the loop that iterates over the replies, displaying the sub-topic count:

```
<%= length(reply.replies) %> Sub-topics
```

3. **Providing a view for sub-topics**

Now, we'll create a new template to display sub-topics. Create a new file at `lib/elxr_bb_web/templates/reply/subtopics.html.eex`:

```
<h2>Sub-topics for "<%= @reply.content %>"</h2>

<%= for subtopic <- @reply.replies do %>
  <div class="subtopic">
    <h3><%= subtopic.content %></h3>
    <p>Posted by <%= subtopic.user.username %> on <%= Timex.format!(subtopic.inserted_at, "%B %-e, %Y") %></p>
  </div>
<% end %>
```

Add a `subtopics` action to the `ReplyController` in `lib/elxr_bb_web/controllers/reply_controller.ex`:

```
def subtopics(conn, %{"id" => id}) do
  reply = ElxrBb.Forum.get_reply!(id)
  render(conn, "subtopics.html", reply: reply)
end
```

In the `lib/elxr_bb_web/router.ex` file, add a new route for the subtopics view:

```
get "/replies/:id/subtopics", ReplyController, :subtopics
```

Finally, update the `lib/elxr_bb_web/templates/topic/show.html.eex` file to include a link to the sub-topics view for each reply:

```
<!-- Add this line below the sub-topic count -->
<p><%= link "View Sub-topics", to: Routes.reply_path(@conn, :subtopics, reply.id) %></p>
```

Now you have successfully implemented sub-topics and displayed sub-topic counts in your elxrBB application. Users can now navigate to a dedicated view to see all the sub-topics under a specific reply.
