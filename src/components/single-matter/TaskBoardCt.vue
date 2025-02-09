<template>
    <div class="task-board">
      <!-- Board Controls -->
      <div class="board-controls">
        <div class="controls-left">
          <!-- <el-button type="primary" @click="showColumnDialog = true" size="small">
            <el-icon><Plus /></el-icon>Add Column
          </el-button> -->
        </div>
        <div v-if="showScrollButtons" class="scroll-controls">
          <div class="scroll-button left" @click="scrollBoard('left')">
            <el-icon><ArrowLeft /></el-icon>
          </div>
          <div class="scroll-button right" @click="scrollBoard('right')">
            <el-icon><ArrowRight /></el-icon>
          </div>
        </div>
      </div>
  
      <!-- Draggable Board -->
      <div class="board-container">
        <draggable
          class="board-columns"
          v-model="columns"
          item-key="id"
          :group="{ name: 'columns' }"
          handle=".column-header">
          <template #item="{ element: column }">
            <div class="board-column">
              <div class="column-header" :style="{ backgroundColor: getHeaderBackgroundColor(column) }">
                <div class="column-title">
                  <el-avatar 
                    v-if="groupBy === 'assignee' && column.assignee" 
                    :size="18"
                    :src="column.avatarUrl">
                    {{ getInitials(column.title) }}
                  </el-avatar>
                  <h3>{{ column.title }}</h3>
                  <span class="task-count">({{ column.tasks.length }})</span>
                </div>
              </div>
              
              <draggable
                class="task-list"
                v-model="column.tasks"
                :group="{ name: 'tasks' }"
                item-key="id"
                @change="(e) => onTaskMove(e, column)">
                <template #item="{ element: task }">
                  <div class="task-card">
                    <div class="task-header">
                      <span class="task-title">{{ task.title }}</span>
                    </div>
                    <div class="task-meta">
                      <el-tag 
                        v-if="groupBy !== 'status'"
                        :type="getStatusType(task)" 
                        size="small">
                        {{ formatStatus(task.status) }}
                      </el-tag>
                      <div class="priority-wrapper">
                        <el-tag 
                          v-if="groupBy !== 'priority'"
                          :type="getPriorityType(task.priority)" 
                          size="small">
                          {{ task.priority }}
                        </el-tag>
                        <el-icon 
                          class="details-icon" 
                          @click.stop="navigateToDetailedView(task)">
                          <View />
                        </el-icon>
                      </div>
                      <div 
                        v-if="groupBy !== 'assignee' && task.assignee"
                        class="assignee">
                        <el-avatar :size="20">
                          {{ getInitials(getAssigneeName(task)) }}
                        </el-avatar>
                      </div>
                    </div>
                  </div>
                </template>
              </draggable>
            </div>
          </template>
        </draggable>
      </div>
  
      <!-- Add/Edit Column Dialog -->
      <el-dialog
        v-model="showColumnDialog"
        :title="editingColumn ? 'Edit Column' : 'Add Column'"
        width="400px">
        <el-form :model="columnForm" label-width="100px">
          <el-form-item label="Title">
            <el-input v-model="columnForm.title" />
          </el-form-item>
          <el-form-item label="Type">
            <el-select v-model="columnForm.type" style="width: 100%">
              <el-option label="Assignee" value="assignee" />
              <el-option label="Custom" value="custom" />
            </el-select>
          </el-form-item>
          <el-form-item v-if="columnForm.type === 'assignee'" label="Assignee">
            <el-select v-model="columnForm.assignee" style="width: 100%">
              <el-option
                v-for="user in sharedUsers"
                :key="user.id"
                :label="user.email"
                :value="user.id"
              />
            </el-select>
          </el-form-item>
        </el-form>
        <template #footer>
          <el-button @click="showColumnDialog = false">Cancel</el-button>
          <el-button type="primary" @click="saveColumn">Save</el-button>
        </template>
      </el-dialog>
    </div>
  </template>
  
  <script>
  import { defineComponent } from 'vue'
  import draggable from 'vuedraggable'
  import { Plus, More, ArrowLeft, ArrowRight, View } from '@element-plus/icons-vue'
  import { ElMessage } from 'element-plus'
  
  export default defineComponent({
    components: {
      draggable,
      Plus,
      More,
      ArrowLeft,
      ArrowRight,
      View
    },
  
    props: {
      tasks: {
        type: Array,
        required: true
      },
      loading: {
        type: Boolean,
        default: false
      },
      groupBy: {
        type: String,
        default: 'status',
        validator: (value) => ['status', 'assignee', 'priority', 'starred_by'].includes(value)
      },
      sharedUsers: {
        type: Array,
        required: true
      },
      filters: {
        type: Object,
        required: true
      }
    },
  
    data() {
      return {
        columns: [],
        showColumnDialog: false,
        editingColumn: null,
        columnForm: {
          title: '',
          type: 'custom',
          assignee: null
        }
      }
    },
  
    methods: {
      initializeColumns() {
        let columns = [];
        
        switch (this.groupBy) {
          case 'status':
            // If status filter is active, only show filtered statuses
            if (this.filters.status?.length) {
              columns = this.filters.status.map(status => ({
                id: status,
                title: this.formatStatus(status),
                tasks: []
              }));
            } else {
              columns = [
                { id: 'not_started', title: 'Not Started', tasks: [] },
                { id: 'in_progress', title: 'In Progress', tasks: [] },
                { id: 'awaiting_external', title: 'Awaiting External', tasks: [] },
                { id: 'completed', title: 'Completed', tasks: [] }
              ];
            }
            break;
            
          case 'priority':
            // If priority filter is active, only show that priority
            if (this.filters.priority) {
              columns = [
                { id: this.filters.priority, title: `${this.filters.priority.charAt(0).toUpperCase()}${this.filters.priority.slice(1)} Priority`, tasks: [] }
              ];
            } else {
              columns = [
                { id: 'high', title: 'High Priority', tasks: [] },
                { id: 'medium', title: 'Medium Priority', tasks: [] },
                { id: 'low', title: 'Low Priority', tasks: [] }
              ];
            }
            break;
            
          case 'assignee':
            // Get the most up-to-date filters
            const savedFilters = localStorage.getItem('taskListFilters');
            const parsedFilters = savedFilters ? JSON.parse(savedFilters) : null;
            const effectiveFilters = parsedFilters?.assignee || this.filters.assignee;
            
            // Always include unassigned column if no assignee filter is active
            // or if the filter includes tasks without assignees
            if (!effectiveFilters?.length || effectiveFilters.includes(null)) {
              columns = [{ id: 'unassigned', title: 'Unassigned', tasks: [] }];
            } else {
              columns = [];
            }
            
            // Get filtered users based on assignee filter
            const filteredUsers = effectiveFilters?.length
              ? this.sharedUsers.filter(user => effectiveFilters.includes(user.id))
              : this.sharedUsers;
              
            columns.push(...filteredUsers.map(user => ({
              id: user.id,
              title: user.email,
              assignee: user.id,
              avatarUrl: user.avatar_url,
              tasks: []
            })));
            break;
            
          case 'starred_by':
            if (this.filters.starredBy?.length) {
              // Create a column for each selected user
              columns = this.filters.starredBy.map(userId => {
                const user = this.sharedUsers.find(u => u.id === userId);
                return {
                  id: userId,
                  title: user?.email || 'Unknown User',
                  tasks: []
                };
              });
            }
            break;
        }
        
        // Distribute tasks to columns
        this.filteredTasks.forEach(task => {
          if (this.groupBy === 'starred_by') {
            // Get all users who starred this task
            const starredByUsers = task.task_stars?.map(star => star.user_id) || [];
            
            // Add task to each user's column who starred it
            starredByUsers.forEach(userId => {
              const column = columns.find(col => col.id === userId);
              if (column) {
                column.tasks.push(task);
              }
            });
          } else {
            const columnId = this.getColumnIdForTask(task);
            const column = columns.find(col => col.id === columnId);
            if (column) {
              column.tasks.push(task);
            }
          }
        });
        
        this.columns = columns;
      },
  
      getColumnIdForTask(task) {
        switch (this.groupBy) {
          case 'status':
            return task.status || 'not_started';
          case 'priority':
            return task.priority || 'medium';
          case 'assignee':
            return task.assignee || 'unassigned';
          case 'starred_by':
            return task.task_stars?.length ? task.task_stars[0].user_id : 'not_starred';
          default:
            return null;
        }
      },
  
      onTaskMove(event, targetColumn) {
        if (!event.added && !event.moved) return;
        
        const task = event.added ? event.added.element : event.moved.element;
        const updates = {};
        
        switch (this.groupBy) {
          case 'status':
            updates.status = targetColumn.id;
            break;
          case 'priority':
            updates.priority = targetColumn.id;
            break;
          case 'assignee':
            updates.assignee = targetColumn.id === 'unassigned' ? null : targetColumn.id;
            break;
        }
        
        this.$emit('update-task', { ...task, ...updates });
      },
  
      handleColumnAction(command, column) {
        if (command === 'edit') {
          this.editingColumn = column
          this.columnForm = {
            title: column.title,
            type: column.type,
            assignee: column.assignee
          }
          this.showColumnDialog = true
        } else if (command === 'delete') {
          this.deleteColumn(column)
        }
      },
  
      saveColumn() {
        if (!this.columnForm.title) {
          ElMessage.warning('Please enter a column title')
          return
        }
  
        if (this.editingColumn) {
          const index = this.columns.findIndex(col => col.id === this.editingColumn.id)
          if (index !== -1) {
            this.columns[index] = {
              ...this.editingColumn,
              ...this.columnForm
            }
          }
        } else {
          this.columns.push({
            id: `custom-${Date.now()}`,
            ...this.columnForm,
            tasks: []
          })
        }
  
        this.showColumnDialog = false
        this.editingColumn = null
        this.resetColumnForm()
      },
  
      deleteColumn(column) {
        // Don't allow deleting assignee columns
        if (column.type === 'assignee') {
          ElMessage.warning('Cannot delete assignee columns')
          return
        }
  
        const index = this.columns.findIndex(col => col.id === column.id)
        if (index !== -1) {
          // Move tasks to unassigned column
          const unassignedColumn = this.columns.find(col => col.id === 'unassigned')
          if (unassignedColumn) {
            unassignedColumn.tasks.push(...column.tasks)
          }
          this.columns.splice(index, 1)
        }
      },
  
      resetColumnForm() {
        this.columnForm = {
          title: '',
          type: 'custom',
          assignee: null
        }
      },
  
      getInitials(name) {
        return name.split(' ').map(n => n[0]).join('').toUpperCase();
      },
  
      getAssigneeName(task) {
        const assignee = this.sharedUsers.find(user => user.id === task.assignee);
        return assignee ? assignee.email : 'Unassigned';
      },
  
      getStatusType(task) {
        switch (task.status) {
          case 'completed':
            return 'success';
          case 'in_progress':
            return 'primary';
          case 'not_started':
            return 'info';
          case 'awaiting_external':
            return 'warning';
          default:
            return 'info';
        }
      },
  
      getPriorityType(priority) {
        switch (priority?.toLowerCase()) {
          case 'high':
            return 'danger';
          case 'medium':
            return 'warning';
          case 'low':
            return 'success';
          default:
            return 'info';
        }
      },
  
      formatStatus(status) {
        const statusMap = {
          'in_progress': 'In Progress',
          'not_started': 'Not Started',
          'completed': 'Completed',
          'awaiting_external': 'Awaiting External'
        };
        return statusMap[status] || status;
      },
  
      scrollBoard(direction) {
        const container = this.$el.querySelector('.board-container');
        const scrollAmount = container.clientWidth * 0.8; // Scroll 80% of the visible width
        
        if (direction === 'left') {
          container.scrollLeft -= scrollAmount;
        } else {
          container.scrollLeft += scrollAmount;
        }
      },
  
      getHeaderBackgroundColor(column) {
        switch (this.groupBy) {
          case 'status':
            switch (column.id) {
              case 'completed':
                return 'var(--el-color-success)';
              case 'in_progress':
                return 'var(--el-color-warning)';
              case 'not_started':
                return 'var(--el-color-info)';
              case 'awaiting_external':
                return 'var(--el-color-warning)';
              default:
                return 'var(--el-color-info)';
            }
          case 'priority':
            switch (column.id) {
              case 'high':
                return 'var(--el-color-danger)';
              case 'medium':
                return 'var(--el-color-warning)';
              case 'low':
                return 'var(--el-color-success)';
              default:
                return 'var(--el-color-info)';
            }
          default:
            return 'var(--el-color-primary)';
        }
      },
  
      navigateToDetailedView(task) {
        this.$router.push(`/single-matter/${task.matter_id}/tasks/${task.id}`);
      }
    },
  
    watch: {
      tasks: {
        handler() {
          this.initializeColumns();
        },
        deep: true
      },
      groupBy() {
        // Get saved filters from localStorage first
        const savedFilters = localStorage.getItem('taskListFilters');
        const parsedFilters = savedFilters ? JSON.parse(savedFilters) : null;
        
        // Create a merged filter state, prioritizing localStorage
        const mergedFilters = { 
          ...this.filters,
          assignee: parsedFilters?.assignee || this.filters.assignee 
        };

        // Initialize columns with the merged filters
        this.initializeColumns();
      },
      filters: {
        handler(newFilters) {
          // Don't save to localStorage here since TasksList component handles that
          this.initializeColumns();
        },
        deep: true
      }
    },
  
    created() {
      this.initializeColumns();
    },
  
    computed: {
      showScrollButtons() {
        return this.columns.length > 4 && window.innerWidth > 768;
      },
      filteredTasks() {
        let tasks = this.tasks.slice();
        
        if (this.filters.starredBy?.length) {
          tasks = tasks.filter(task => 
            task.task_stars?.some(star => 
              this.filters.starredBy.includes(star.user_id)
            )
          );
        }
        
        return tasks;
      }
    },
  
    emits: ['update-task', 'update:filters']
  })
  </script>
  
  <style scoped>
  .task-board {
    height: 100%;
    overflow: hidden;
    padding: 16px;
    background: var(--el-fill-color-blank);
  }
  
  .board-controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 10px;
  }
  
  .controls-left {
    display: flex;
    gap: 8px;
  }
  
  .scroll-controls {
    display: flex;
    gap: 8px;
    transition: opacity 0.3s ease;
  }
  
  .scroll-button {
    width: 30px;
    height: 30px;
    background: white;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease;
    border: 1px solid var(--el-border-color-lighter);
  }
  
  .scroll-button:hover {
    background: var(--el-color-primary-light-9);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  }
  
  .board-container {
    height: 100%;
    overflow-x: auto;
    padding: 0.35rem 0;
    position: relative;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch;
  }
  
  /* Hide scrollbar but maintain functionality */
  .board-container::-webkit-scrollbar {
    height: 0;
    width: 0;
    background: transparent;
  }
  
  @media (max-width: 768px) {
    .scroll-controls {
      display: none;
    }
    
    .board-container {
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
      scroll-snap-type: x mandatory;
    }
    
    .board-column {
      scroll-snap-align: start;
    }
  }
  
  .board-columns {
    display: flex;
    gap: 1rem;
    min-height: 100%;
    padding: 0.5rem;
  }
  
  .board-column {
    flex: 0 0 300px;
    background: var(--el-fill-color-light);
    border-radius: 12px;
    display: flex;
    flex-direction: column;
    max-height: 100%;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
    border: 1px solid var(--el-border-color-lighter);
  }
  
  .column-header {
    padding: 11px 14px;
    border-radius: 12px 12px 0 0;
    transition: background-color 0.3s ease;
  }
  
  .column-title {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  
  .column-title h3 {
    margin: 0;
    font-size: 1rem;
    color: #ffffff;
    font-weight: 600;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  }
  
  .task-count {
    color: #ffffff;
    font-size: 0.85rem;
    background: rgba(255, 255, 255, 0.2);
    padding: 2px 8px;
    border-radius: 12px;
  }

  .task-list {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  
  .task-card {
    background: white;
    border-radius: 8px;
    padding: 1rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    border: 1px solid var(--el-border-color-lighter);
    cursor: move;
    transition: all 0.2s ease;
  }
  
  .task-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    border-color: var(--el-border-color);
  }
  
  .task-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 12px;
  }
  
  .task-title {
    font-weight: 500;
    font-size: 0.95rem;
    color: var(--el-text-color-primary);
    flex: 1;
    min-width: 0;
    word-break: break-word;
    line-height: 1.4;
  }
  
  .task-meta {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    margin-top: 0.75rem;
    flex-wrap: wrap;
  }
  
  /* .task-meta .el-tag {
    border-radius: 6px;
    padding: 0 8px;
    height: 24px;
    line-height: 24px;
  } */
  
  .assignee {
    margin-left: auto;
  }
  
  .assignee .el-avatar {
    border: 2px solid white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
  
  .more-icon {
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
  }
  
  .more-icon:hover {
    background: var(--el-fill-color-darker);
  }
  
  .priority-wrapper {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  
  .details-icon {
    cursor: pointer;
    padding: 4px;
    color: var(--el-color-primary);
    transition: all 0.2s ease;
    border-radius: 4px;
    font-size: 14px;
  }
  
  .details-icon:hover {
    background: var(--el-color-primary-light-9);
    transform: translateY(-1px);
  }
  
  @media (max-width: 768px) {
    .task-board {
      padding: 8px;
    }
    
    .board-column {
      flex: 0 0 280px;
    }
    
    .task-card {
      padding: 12px;
    }
    
    .task-meta {
      gap: 0.5rem;
    }
    
    .task-meta .el-tag {
      font-size: 0.85rem;
    }
  }
  </style> 