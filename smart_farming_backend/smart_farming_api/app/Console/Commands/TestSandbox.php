<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use App\Enums\TaskStatus;
use App\Models\Task;

#[Signature('app:test-sandbox')]
#[Description('Command description')]
class TestSandbox extends Command
{
    /**
     * Execute the console command.
     */
    public function handle()
    {
        dump([
            'enum_case' => TaskStatus::Selesai,
            'enum_value' => TaskStatus::Selesai->value,
            'is_same' => TaskStatus::Selesai === TaskStatus::Selesai,
            'new_task' => (new Task())->toArray(),
        ]);
    }
}
