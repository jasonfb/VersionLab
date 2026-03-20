class CreateSolidQueueAndCableTables < ActiveRecord::Migration[8.1]
  def change
    # Solid Cache
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
    end
    add_index :solid_cache_entries, :key_hash, unique: true, if_not_exists: true
    add_index :solid_cache_entries, :byte_size, if_not_exists: true
    add_index :solid_cache_entries, [ :key_hash, :byte_size ], if_not_exists: true

    # Solid Cable
    create_table :solid_cable_messages, if_not_exists: true do |t|
      t.binary :channel, null: false
      t.bigint :channel_hash, null: false
      t.binary :payload, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_cable_messages, :channel, if_not_exists: true
    add_index :solid_cable_messages, :channel_hash, if_not_exists: true
    add_index :solid_cable_messages, :created_at, if_not_exists: true

    # Solid Queue
    create_table :solid_queue_jobs, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.string :concurrency_key
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :solid_queue_jobs, :active_job_id, if_not_exists: true
    add_index :solid_queue_jobs, :class_name, if_not_exists: true
    add_index :solid_queue_jobs, :finished_at, if_not_exists: true
    add_index :solid_queue_jobs, [ :queue_name, :finished_at ], name: "index_solid_queue_jobs_for_filtering", if_not_exists: true
    add_index :solid_queue_jobs, [ :scheduled_at, :finished_at ], name: "index_solid_queue_jobs_for_alerting", if_not_exists: true

    create_table :solid_queue_blocked_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_blocked_executions, :job_id, unique: true, if_not_exists: true
    add_index :solid_queue_blocked_executions, [ :concurrency_key, :priority, :job_id ], name: "index_solid_queue_blocked_executions_for_release", if_not_exists: true
    add_index :solid_queue_blocked_executions, [ :expires_at, :concurrency_key ], name: "index_solid_queue_blocked_executions_for_maintenance", if_not_exists: true

    create_table :solid_queue_claimed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_claimed_executions, :job_id, unique: true, if_not_exists: true
    add_index :solid_queue_claimed_executions, [ :process_id, :job_id ], if_not_exists: true

    create_table :solid_queue_failed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_failed_executions, :job_id, unique: true, if_not_exists: true

    create_table :solid_queue_pauses, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_pauses, :queue_name, unique: true, if_not_exists: true

    create_table :solid_queue_processes, if_not_exists: true do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.string :name, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_processes, :last_heartbeat_at, if_not_exists: true
    add_index :solid_queue_processes, [ :name, :supervisor_id ], unique: true, if_not_exists: true
    add_index :solid_queue_processes, :supervisor_id, if_not_exists: true

    create_table :solid_queue_ready_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_ready_executions, :job_id, unique: true, if_not_exists: true
    add_index :solid_queue_ready_executions, [ :priority, :job_id ], name: "index_solid_queue_poll_all", if_not_exists: true
    add_index :solid_queue_ready_executions, [ :queue_name, :priority, :job_id ], name: "index_solid_queue_poll_by_queue", if_not_exists: true

    create_table :solid_queue_recurring_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_recurring_executions, :job_id, unique: true, if_not_exists: true
    add_index :solid_queue_recurring_executions, [ :task_key, :run_at ], unique: true, if_not_exists: true

    create_table :solid_queue_recurring_tasks, if_not_exists: true do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :class_name
      t.string :command, limit: 2048
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :solid_queue_recurring_tasks, :key, unique: true, if_not_exists: true
    add_index :solid_queue_recurring_tasks, :static, if_not_exists: true

    create_table :solid_queue_scheduled_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_scheduled_executions, :job_id, unique: true, if_not_exists: true
    add_index :solid_queue_scheduled_executions, [ :scheduled_at, :priority, :job_id ], name: "index_solid_queue_dispatch_all", if_not_exists: true

    create_table :solid_queue_semaphores, if_not_exists: true do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :solid_queue_semaphores, :key, unique: true, if_not_exists: true
    add_index :solid_queue_semaphores, [ :key, :value ], if_not_exists: true
    add_index :solid_queue_semaphores, :expires_at, if_not_exists: true

    # Foreign keys for Solid Queue
    add_foreign_key :solid_queue_blocked_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
    add_foreign_key :solid_queue_claimed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
    add_foreign_key :solid_queue_failed_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
    add_foreign_key :solid_queue_ready_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
    add_foreign_key :solid_queue_recurring_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
    add_foreign_key :solid_queue_scheduled_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade, if_not_exists: true
  end
end
